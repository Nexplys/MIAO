Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "../../../src/Miao.Files.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "../../../src/Miao.Settings.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "../../../src/Miao.Http.psm1") -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "../../../src/Miao.Web.psm1") -ErrorAction Stop

function Get-TunicValue {
    param($Object, [string]$Key, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Key)) { return $Object[$Key] }
    }
    elseif ($null -ne $Object.PSObject.Properties[$Key]) { return $Object.$Key }
    return $Default
}

function Get-TunicCount {
    param($Object, [string]$Key)
    $value = Get-TunicValue $Object $Key
    if ($null -eq $value -or $value -is [bool] -or $value -is [string]) {
        throw "Compteur absent ou invalide : $Key"
    }
    $number = 0
    if (-not [int]::TryParse([string]$value, [ref]$number) -or $number -lt 0) {
        throw "Compteur invalide : $Key"
    }
    return $number
}

function New-TunicItems {
    return [ordered]@{
        red = 0; green = 0; blue = 0; sword = 0; laurels = 0
        prayer = 0; holyCross = 0; wand = 0; orb = 0; lantern = 0
        mask = 0; houseKey = 0; gold = 0
    }
}

function ConvertTo-MiaoTunicSnapshot {
    param([Parameter(Mandatory = $true)]$Tracker, [Parameter(Mandatory = $true)]$Settings)
    $seed = Get-TunicCount $Tracker "Seed"
    $scene = Get-TunicValue $Tracker "CurrentScene"
    if ($null -eq $scene -or $null -eq $scene.PSObject.Properties["SceneName"]) {
        throw "Scene absente du tracker."
    }
    $inventory = Get-TunicValue $Tracker "ImportantItems"
    if ($null -eq $inventory) { throw "Inventaire absent du tracker." }
    $items = New-TunicItems
    $mapping = [ordered]@{
        red = "Hexagon Red"; green = "Hexagon Green"; blue = "Hexagon Blue"
        laurels = "Hyperdash"; prayer = "Prayer"; holyCross = "Holy Cross"
        wand = "Techbow"; orb = "Wand"; lantern = "Lantern"
        mask = "Mask"; houseKey = "Key (House)"
    }
    foreach ($key in $mapping.Keys) {
        $items[$key] = [System.Math]::Min(1, (Get-TunicCount $inventory $mapping[$key]))
    }
    $items.gold = Get-TunicCount $inventory "Hexagon Gold"
    $stick = Get-TunicCount $inventory "Stick"
    $sword = Get-TunicCount $inventory "Sword"
    $progression = Get-TunicCount $inventory "Sword Progression"
    if ($Settings.swordProgression -and $progression -gt 0) {
        $items.sword = [System.Math]::Min(4, $progression)
    }
    elseif ($sword -gt 0) { $items.sword = 2 }
    elseif ($stick -gt 0) { $items.sword = 1 }
    if (-not $Settings.abilityShuffling) { $items.prayer = 1; $items.holyCross = 1 }
    $sceneName = [string]$scene.SceneName
    return [pscustomobject]@{
        Seed = $seed
        # Some randomizer versions leave SceneName null during a valid game.
        Active = ($seed -ne 0 -and
            $sceneName -notin @("TitleScreen", "Loading"))
        Items = $items
    }
}

function ConvertFrom-MiaoTunicYaml {
    param([Parameter(Mandatory = $true)][string]$Text)
    if ($Text.Length -gt 65536) { throw "YAML trop volumineux (64 K caracteres maximum)." }
    # Deliberately parse only deterministic scalar options in the TUNIC block.
    # Weighted choices, aliases and expressions cannot describe a resolved seed.
    $mapping = @{
        sword_progression = "swordProgression"; ability_shuffling = "abilityShuffling"
        hexagon_quest = "hexagonQuest"; hexagon_goal = "hexagonGoal"
    }
    $options = @{}
    $inBlock = $false
    $found = $false
    $unsupported = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "\r?\n")) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -cmatch '^TUNIC:\s*(#.*)?$') {
            if ($found) { throw "Plusieurs sections TUNIC dans le YAML." }
            $found = $true; $inBlock = $true; continue
        }
        if ($line -match '^\S') { $inBlock = $false }
        if (-not $inBlock) { continue }
        if ($line -match "`t") { throw "Utiliser des espaces pour indenter le YAML." }
        if ($line -notmatch '^  ([a-z_]+):\s*(.*?)\s*$') { continue }
        $key = $Matches[1]
        $value = ($Matches[2] -replace '\s+#.*$', '').Trim().Trim([char[]]@("'", '"'))
        if ($mapping.ContainsKey($key)) {
            $target = $mapping[$key]
            if ($options.ContainsKey($target)) { throw "Option YAML dupliquee : $key" }
            if ($key -eq "hexagon_goal") {
                $goal = 0
                if (-not [int]::TryParse($value, [ref]$goal) -or $goal -lt 1 -or $goal -gt 100) {
                    throw "hexagon_goal doit etre un entier entre 1 et 100."
                }
                $options[$target] = $goal
            }
            else {
                if ($value -cnotmatch '^(true|false)$') {
                    throw "L'option $key doit etre true ou false, sans choix pondere."
                }
                $options[$target] = ($value -eq "true")
            }
        }
        elseif ($key -in @("shuffle_ladders", "shuffle_fuses", "shuffle_bells", "grass_randomizer", "breakable_shuffle") -and $value -ne "false") {
            $unsupported.Add($key)
        }
    }
    if (-not $found -or $options.Count -ne 4) {
        throw "YAML TUNIC incomplet : sword_progression, ability_shuffling, hexagon_quest et hexagon_goal requis."
    }
    return [pscustomobject]@{ Options = $options; Unsupported = @($unsupported.ToArray()) }
}

function Initialize-MiaoTunicModule {
    param($ApplicationContext, [string]$ModulePath, $Options = @{})
    $schema = Import-MiaoSettingsSchema -Path (Join-Path $ModulePath "config/settings.schema.json")
    $path = Join-Path $ApplicationContext.RuntimePath "tunic/settings.json"
    $settings = Read-MiaoSettings -Path $path -Schema $schema
    $profile = [Environment]::GetFolderPath("UserProfile")
    if ([string]::IsNullOrWhiteSpace($profile)) { $profile = $env:USERPROFILE }
    $defaultPath = Join-Path $profile "AppData/LocalLow/Andrew Shouldice/Secret Legend/Randomizer/ItemTracker.json"
    $state = [pscustomobject]@{
        Schema = $schema; Settings = $settings; SettingsPath = $path
        DefaultPath = [string](Get-TunicValue $Options "TrackerPath" $defaultPath)
        SourcePath = ""; Signature = ""; Snapshot = $null; SnapshotTimeUtc = [DateTime]::MinValue
        Status = "waiting"; Detail = ""; Session = [Guid]::NewGuid().ToString("N"); Generation = 0
        SimulationEnabled = $false; SimulationItems = (New-TunicItems)
        GameRunning = $false; GameStartedUtc = [DateTime]::MinValue
        NextProcessCheckUtc = [DateTime]::MinValue
        Catalog = (Read-MiaoUtf8File -Path (Join-Path $ModulePath "public/catalog.json") | ConvertFrom-Json)
    }
    return $state
}

function Update-MiaoTunicSource {
    param($State, [DateTime]$Now)
    $path = if ([string]::IsNullOrWhiteSpace($State.Settings.sourcePath)) { $State.DefaultPath } else { $State.Settings.sourcePath }
    if ($path -ne $State.SourcePath) {
        $State.SourcePath = $path; $State.Signature = ""; $State.Snapshot = $null; $State.Generation++
    }
    try {
        if ($path -notmatch '^[A-Za-z]:[\\/]') { throw "Choisir un fichier sur un disque local." }
        $file = [System.IO.FileInfo]::new($path)
        if (-not $file.Exists) { $State.Status = "missing"; $State.Detail = "Fichier introuvable."; return }
        if ($file.Length -eq 0 -or $file.Length -gt 4194304) { throw "Fichier vide ou trop volumineux (4 Mio maximum)." }
        $signature = "$($file.LastWriteTimeUtc.Ticks):$($file.Length)"
        if ($signature -ne $State.Signature) {
            $tracker = Read-MiaoUtf8File -Path $path | ConvertFrom-Json
            $snapshot = ConvertTo-MiaoTunicSnapshot -Tracker $tracker -Settings $State.Settings
            if ($null -eq $State.Snapshot -or $snapshot.Seed -ne $State.Snapshot.Seed) { $State.Generation++ }
            $State.Snapshot = $snapshot
            $State.SnapshotTimeUtc = $file.LastWriteTimeUtc
            $State.Signature = $signature
        }
        $State.Status = "live"
        if (-not $State.Snapshot.Active) { $State.Status = "waiting" }
        elseif ($State.Settings.hideWhenGameClosed -and -not $State.GameRunning) { $State.Status = "closed" }
        elseif ($State.Settings.hideWhenGameClosed -and $file.LastWriteTimeUtc -lt $State.GameStartedUtc) {
            $State.Status = "waiting"
        }
        $State.Detail = ""
    }
    catch {
        $State.Status = "retrying"
        $State.Detail = "Lecture en attente : $($_.Exception.Message)"
        # Keep the last valid snapshot; never replace it with partial data.
    }
}

function Update-MiaoTunicModule {
    param($State, [DateTime]$Now)
    if ($Now -ge $State.NextProcessCheckUtc) {
        $State.GameRunning = $false
        $State.GameStartedUtc = [DateTime]::MinValue
        foreach ($process in @([System.Diagnostics.Process]::GetProcessesByName("TUNIC"))) {
            try {
                $State.GameRunning = $true
                $State.GameStartedUtc = $process.StartTime.ToUniversalTime()
            }
            catch { }
            finally { $process.Dispose() }
        }
        $State.NextProcessCheckUtc = $Now.AddSeconds(2)
    }
    Update-MiaoTunicSource -State $State -Now $Now
}

function Get-MiaoTunicPublicState {
    param($State)
    $items = New-TunicItems
    $visible = $false
    if ($null -ne $State.Snapshot) {
        $items = $State.Snapshot.Items
        $visible = $State.Snapshot.Active -and $State.Status -in @("live", "retrying")
        if ($State.Settings.hideWhenGameClosed -and -not $State.GameRunning) { $visible = $false }
        if ($State.Settings.hideWhenGameClosed -and $State.SnapshotTimeUtc -lt $State.GameStartedUtc) { $visible = $false }
    }
    if ($State.SimulationEnabled) { $items = $State.SimulationItems; $visible = $true }
    $appearance = [ordered]@{}
    foreach ($key in @("iconSize", "gap", "missingOpacity", "showLabels", "showPanels", "animateAcquisitions", "hexagonQuest", "hexagonGoal")) {
        $appearance[$key] = $State.Settings[$key]
    }
    return [ordered]@{
        ok = $true; visible = [bool]($visible -and $State.Settings.widgetEnabled)
        mode = $(if ($State.SimulationEnabled) { "simulation" } else { "live" })
        status = $State.Status; session = "$($State.Session):$($State.Generation)"
        items = $items; appearance = $appearance
    }
}

function Save-MiaoTunicSettings {
    param($State, $Payload)
    $settings = ConvertTo-MiaoSettings -InputObject $Payload -Schema $State.Schema
    if ($settings.sourcePath -and $settings.sourcePath -notmatch '^[A-Za-z]:[\\/]') {
        throw "Le chemin doit designer un fichier sur un disque local."
    }
    Save-MiaoSettings -Settings $settings -Path $State.SettingsPath
    $State.Settings = $settings; $State.Signature = ""; $State.Generation++
    Update-MiaoTunicModule -State $State -Now ([DateTime]::UtcNow)
}

function Invoke-MiaoTunicRoute {
    param($Request, $State, $ApplicationContext, $Client)
    $methods = @{
        "/api/tunic/state" = "GET"; "/api/tunic/config" = "GET"
        "/api/tunic/settings" = "POST"; "/api/tunic/profile" = "POST"
        "/api/tunic/simulation" = "POST"
    }
    if (-not $methods.ContainsKey($Request.Path)) { return $false }
    if (-not (Test-MiaoRequestMethod -Request $Request -Expected $methods[$Request.Path] -Client $Client)) { return $true }
    $result = @{ ok = $true }
    switch ($Request.Path) {
        "/api/tunic/state" { $result = Get-MiaoTunicPublicState -State $State }
        "/api/tunic/config" {
            $result = @{ ok = $true; settings = $State.Settings; schema = $State.Schema
                catalog = @($State.Catalog); sourcePath = $State.SourcePath; detail = $State.Detail }
        }
        "/api/tunic/settings" {
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            Save-MiaoTunicSettings -State $State -Payload $payload
            $result = @{ ok = $true; settings = $State.Settings }
        }
        "/api/tunic/profile" {
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $profile = ConvertFrom-MiaoTunicYaml -Text ([string](Get-TunicValue $payload "yaml" ""))
            $next = [ordered]@{}
            foreach ($key in $State.Settings.Keys) { $next[$key] = $State.Settings[$key] }
            foreach ($key in $profile.Options.Keys) { $next[$key] = $profile.Options[$key] }
            Save-MiaoTunicSettings -State $State -Payload $next
            $result = @{ ok = $true; settings = $State.Settings; unsupported = @($profile.Unsupported) }
        }
        "/api/tunic/simulation" {
            $payload = ConvertFrom-MiaoEncodedJson -Body $Request.Body
            $enabled = Get-TunicValue $payload "enabled"
            if ($enabled -isnot [bool]) { throw "enabled doit etre un booleen." }
            $items = $State.SimulationItems
            $provided = Get-TunicValue $payload "items"
            if ($null -ne $provided) {
                $items = New-TunicItems
                foreach ($key in @($items.Keys)) {
                    $maximum = if ($key -eq "sword") { 4 } elseif ($key -eq "gold") { 999 } else { 1 }
                    $items[$key] = [System.Math]::Min($maximum, (Get-TunicCount $provided $key))
                }
            }
            if ($enabled -ne $State.SimulationEnabled) { $State.Generation++ }
            $State.SimulationEnabled = $enabled; $State.SimulationItems = $items
            $result = Get-MiaoTunicPublicState -State $State
        }
    }
    Send-MiaoJsonResponse -Client $Client -Value $result
    return $true
}

Export-ModuleMember -Function Initialize-MiaoTunicModule, Update-MiaoTunicModule, Invoke-MiaoTunicRoute, `
    ConvertTo-MiaoTunicSnapshot, ConvertFrom-MiaoTunicYaml, Update-MiaoTunicSource, Get-MiaoTunicPublicState
