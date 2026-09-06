Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$modulePath = Join-Path $root "modules/tunic"
Import-Module (Join-Path $modulePath "server/Miao.Tunic.psm1") -Force
function Assert-Tunic($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ("miao-tunic-" + [Guid]::NewGuid().ToString("N"))
try {
    $source = Join-Path $temporary "ItemTracker.json"
    $state = Initialize-MiaoTunicModule -ApplicationContext @{ RuntimePath = $temporary } -ModulePath $modulePath -Options @{ TrackerPath = $source }
    $state.Settings.hideWhenGameClosed = $false
    $inventory = @{}
    foreach ($key in @("Hexagon Red", "Hexagon Green", "Hexagon Blue", "Hyperdash", "Prayer", "Holy Cross", "Techbow", "Wand", "Lantern", "Mask", "Key (House)", "Hexagon Gold", "Stick", "Sword", "Sword Progression")) { $inventory[$key] = 0 }
    $tracker = @{ Seed = 123; CurrentScene = @{ SceneName = "Overworld" }; ImportantItems = $inventory }
    function Write-Tracker { [IO.File]::WriteAllText($source, ($tracker | ConvertTo-Json -Depth 6)) }
    Update-MiaoTunicSource $state ([DateTime]::UtcNow)
    Assert-Tunic ($state.Status -eq "missing") "Absent source must be reported"
    $inventory.Techbow = 1
    $tracker.CurrentScene.SceneName = $null
    Write-Tracker
    Update-MiaoTunicSource $state ([DateTime]::UtcNow)
    $public = Get-MiaoTunicPublicState $state
    Assert-Tunic ($public.visible -and $public.items.wand -eq 1 -and $public.items.orb -eq 0) "Techbow must map to magic wand"
    Assert-Tunic ($state.Snapshot.Active) "A valid seed with null SceneName must remain active"
    $tracker.Seed = 0
    $reset = ConvertTo-MiaoTunicSnapshot ($tracker | ConvertTo-Json -Depth 6 | ConvertFrom-Json) $state.Settings
    Assert-Tunic (-not $reset.Active) "A reset tracker with null scene must stay hidden"
    $tracker.Seed = 123
    foreach ($level in 1..4) {
        $inventory['Sword Progression'] = $level
        $snapshot = ConvertTo-MiaoTunicSnapshot ($tracker | ConvertTo-Json -Depth 6 | ConvertFrom-Json) $state.Settings
        Assert-Tunic ($snapshot.Items.sword -eq $level) "Sword progression mismatch"
    }
    [IO.File]::WriteAllText($source, '{"Seed":')
    Update-MiaoTunicSource $state ([DateTime]::UtcNow)
    Assert-Tunic ($state.Status -eq "retrying" -and (Get-MiaoTunicPublicState $state).visible) "Partial file must retain valid state"
    $state.Settings.hideWhenGameClosed = $true
    $state.GameRunning = $true
    $state.GameStartedUtc = [DateTime]::UtcNow.AddSeconds(1)
    Assert-Tunic (-not (Get-MiaoTunicPublicState $state).visible) "Old session must remain hidden during partial write"
    $state.Settings.hideWhenGameClosed = $false
    $tracker.Seed = 456
    Write-Tracker
    Update-MiaoTunicSource $state ([DateTime]::UtcNow)
    Assert-Tunic ($state.Status -eq "live" -and (Get-MiaoTunicPublicState $state).session -ne $public.session) "New seed must establish new session"
    $tracker.CurrentScene.SceneName = "TitleScreen"
    Write-Tracker
    Update-MiaoTunicSource $state ([DateTime]::UtcNow)
    Assert-Tunic (-not (Get-MiaoTunicPublicState $state).visible) "Title screen must be hidden"
    $yaml = "TUNIC:`n  sword_progression: true`n  ability_shuffling: true`n  hexagon_quest: false`n  hexagon_goal: 20`n"
    $profile = ConvertFrom-MiaoTunicYaml $yaml
    Assert-Tunic ($profile.Options.swordProgression -and -not $profile.Options.hexagonQuest) "Scalar YAML options mismatch"
    foreach ($invalid in @($yaml.Replace('true', 'random'), ($yaml + '  hexagon_goal: 25'), $yaml.Replace('20', '0'))) {
        $rejected = $false
        try { ConvertFrom-MiaoTunicYaml $invalid | Out-Null } catch { $rejected = $true }
        Assert-Tunic $rejected "Ambiguous YAML must be rejected"
    }
    Write-Host "OK - Tunic : inventaire, sessions, lecture partielle et YAML."
}
finally {
    $resolved = [IO.Path]::GetFullPath($temporary)
    if ([IO.Path]::GetDirectoryName($resolved) -ne [IO.Path]::GetTempPath().TrimEnd('\') -or [IO.Path]::GetFileName($resolved) -notlike 'miao-tunic-*') { throw "Unsafe test cleanup" }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
