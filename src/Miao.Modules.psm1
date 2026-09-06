Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -ErrorAction Stop

$script:ReservedAliasRoutes = @(
    "/control",
    "/miao-control.html",
    "/assets/control.css",
    "/assets/api.js",
    "/assets/control.js",
    "/api/modules",
    "/health",
    "/favicon.ico"
)

function Get-MiaoManifestValue {
    param($Object, [string]$Name, $Fallback)

    if ($null -eq $Object) {
        return $Fallback
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Fallback
    }

    return $property.Value
}

function Resolve-MiaoContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $base $ChildPath))
    $prefix = $base.TrimEnd([char[]]@('\', '/')) +
        [System.IO.Path]::DirectorySeparatorChar

    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    if (-not $candidate.StartsWith($prefix, $comparison)) {
        throw "Chemin de module hors de son dossier : $ChildPath"
    }

    return $candidate
}

function Get-MiaoContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { return "text/html; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".js" { return "text/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".svg" { return "image/svg+xml" }
        ".png" { return "image/png" }
        ".jpg" { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".webp" { return "image/webp" }
        ".gif" { return "image/gif" }
        ".mp3" { return "audio/mpeg" }
        ".ogg" { return "audio/ogg" }
        ".wav" { return "audio/wav" }
        ".woff" { return "font/woff" }
        ".woff2" { return "font/woff2" }
        default { return "application/octet-stream" }
    }
}

function Get-MiaoModulePublicFilePath {
    param(
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$PublicRoot,
        [Parameter(Mandatory = $true)][string]$Url
    )

    $prefix = "/modules/$ModuleId/"
    if (-not $Url.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        throw "La ressource publique doit commencer par $prefix : $Url"
    }

    $relativeUrl = $Url.Substring($prefix.Length)
    $decoded = [System.Uri]::UnescapeDataString($relativeUrl)
    if ([string]::IsNullOrWhiteSpace($decoded) -or
        $decoded.IndexOf('\') -ge 0 -or
        $decoded.IndexOf([char]0) -ge 0 -or
        $decoded.IndexOf('?') -ge 0 -or
        $decoded.IndexOf('#') -ge 0) {
        throw "URL de ressource publique invalide : $Url"
    }

    $segments = @($decoded.Split('/'))
    if ($segments.Count -eq 0 -or
        $segments -contains "" -or
        $segments -contains "." -or
        $segments -contains "..") {
        throw "URL de ressource publique invalide : $Url"
    }

    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    $relativePath = $segments -join $separator
    return Resolve-MiaoContainedPath `
        -BasePath $PublicRoot `
        -ChildPath $relativePath
}

function Assert-MiaoModulePublicAsset {
    param(
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$PublicRoot,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string[]]$AllowedExtensions
    )

    $filePath = Get-MiaoModulePublicFilePath `
        -ModuleId $ModuleId `
        -PublicRoot $PublicRoot `
        -Url $Url
    if (-not [System.IO.File]::Exists($filePath)) {
        throw "Ressource publique de module introuvable : $filePath"
    }

    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
    if ($AllowedExtensions -notcontains $extension) {
        throw "Type de ressource publique invalide : $Url"
    }
}

function Assert-MiaoModuleHookName {
    param(
        [AllowEmptyString()][string]$Name,
        [string]$Label,
        [bool]$Required = $false
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        if ($Required) {
            throw "Hook de module obligatoire absent : $Label"
        }
        return
    }

    if ($Name -notmatch '^[A-Za-z][A-Za-z0-9-]*$') {
        throw "Nom de hook de module invalide : $Name"
    }
}

function Read-MiaoModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $manifestPath = [System.IO.Path]::GetFullPath($Path)
    $modulePath = [System.IO.Directory]::GetParent($manifestPath).FullName
    $manifest = Read-MiaoUtf8File -Path $manifestPath | ConvertFrom-Json

    if ([int](Get-MiaoManifestValue $manifest "schemaVersion" 0) -ne 1) {
        throw "Version de manifeste de module non prise en charge : $manifestPath"
    }

    $id = [string](Get-MiaoManifestValue $manifest "id" "")
    if ($id -notmatch '^[a-z][a-z0-9-]*$') {
        throw "Identifiant de module invalide : $id"
    }
    if ([System.IO.Path]::GetFileName($modulePath) -cne $id) {
        throw "Le dossier du module doit porter son identifiant : $id"
    }

    $name = [string](Get-MiaoManifestValue $manifest "name" "")
    $version = [string](Get-MiaoManifestValue $manifest "version" "")
    $entry = [string](Get-MiaoManifestValue $manifest "entry" "")
    if ([string]::IsNullOrWhiteSpace($name) -or
        $version -notmatch '^\d+\.\d+\.\d+$' -or
        [string]::IsNullOrWhiteSpace($entry)) {
        throw "Manifeste de module incomplet : $manifestPath"
    }

    $enabled = Get-MiaoManifestValue $manifest "enabled" $true
    if ($enabled -isnot [bool]) {
        throw "La propriete enabled du module $id doit etre un booleen."
    }

    $entryPath = Resolve-MiaoContainedPath -BasePath $modulePath -ChildPath $entry
    if (-not [System.IO.File]::Exists($entryPath) -or
        [System.IO.Path]::GetExtension($entryPath) -ine ".psm1") {
        throw "Point d'entree de module invalide : $entryPath"
    }

    $hooks = Get-MiaoManifestValue $manifest "hooks" $null
    if ($null -eq $hooks) {
        throw "Hooks de module absents : $manifestPath"
    }
    Assert-MiaoModuleHookName `
        -Name ([string](Get-MiaoManifestValue $hooks "initialize" "")) `
        -Label "initialize" `
        -Required $true
    foreach ($hookName in @("update", "route", "shutdown")) {
        Assert-MiaoModuleHookName `
            -Name ([string](Get-MiaoManifestValue $hooks $hookName "")) `
            -Label $hookName
    }

    $interval = 1000
    if (-not [int]::TryParse(
        [string](Get-MiaoManifestValue $manifest "updateIntervalMs" 1000),
        [ref]$interval
    ) -or $interval -lt 50 -or $interval -gt 60000) {
        throw "Intervalle de mise a jour invalide pour le module $id."
    }

    $publicDefinition = Get-MiaoManifestValue $manifest "public" $null
    $publicRoot = $null
    if ($null -ne $publicDefinition) {
        $publicRootValue = [string](Get-MiaoManifestValue $publicDefinition "root" "")
        if ([string]::IsNullOrWhiteSpace($publicRootValue)) {
            throw "Dossier public non declare pour le module $id."
        }

        $publicRoot = Resolve-MiaoContainedPath `
            -BasePath $modulePath `
            -ChildPath $publicRootValue
        if (-not [System.IO.Directory]::Exists($publicRoot)) {
            throw "Dossier public de module introuvable : $publicRoot"
        }

        $aliasRoutes = @{}
        foreach ($alias in @(Get-MiaoManifestValue $publicDefinition "aliases" @())) {
            $route = [string](Get-MiaoManifestValue $alias "route" "")
            $file = [string](Get-MiaoManifestValue $alias "file" "")
            if ($route -notmatch '^/[^\s?#\\]*$' -or
                $route.StartsWith("/modules/", [System.StringComparison]::Ordinal) -or
                $route.StartsWith("/api/", [System.StringComparison]::Ordinal) -or
                $script:ReservedAliasRoutes -contains $route) {
                throw "Alias public de module invalide ou reserve : $route"
            }
            if ($aliasRoutes.ContainsKey($route)) {
                throw "Alias public duplique dans le module $id : $route"
            }
            $aliasRoutes[$route] = $true

            $aliasPath = Resolve-MiaoContainedPath `
                -BasePath $publicRoot `
                -ChildPath $file
            if (-not [System.IO.File]::Exists($aliasPath)) {
                throw "Cible d'alias publique introuvable : $aliasPath"
            }
        }
    }

    $control = Get-MiaoManifestValue $manifest "control" $null
    if ($null -ne $control) {
        if ($null -eq $publicRoot) {
            throw "Le module $id declare un dock sans dossier public."
        }

        foreach ($style in @(Get-MiaoManifestValue $control "styles" @())) {
            Assert-MiaoModulePublicAsset `
                -ModuleId $id `
                -PublicRoot $publicRoot `
                -Url ([string]$style) `
                -AllowedExtensions @(".css")
        }
        foreach ($script in @(Get-MiaoManifestValue $control "scripts" @())) {
            Assert-MiaoModulePublicAsset `
                -ModuleId $id `
                -PublicRoot $publicRoot `
                -Url ([string]$script) `
                -AllowedExtensions @(".js")
        }

        $tabIds = @{}
        foreach ($tab in @(Get-MiaoManifestValue $control "tabs" @())) {
            $tabId = [string](Get-MiaoManifestValue $tab "id" "")
            $tabLabel = [string](Get-MiaoManifestValue $tab "label" "")
            $fragment = [string](Get-MiaoManifestValue $tab "fragment" "")
            if ($tabId -notmatch '^[a-z][a-z0-9-]*$' -or
                [string]::IsNullOrWhiteSpace($tabLabel)) {
                throw "Onglet de dock invalide dans le module $id."
            }
            if ($tabIds.ContainsKey($tabId)) {
                throw "Onglet de dock duplique dans le module $id : $tabId"
            }
            $tabIds[$tabId] = $true
            Assert-MiaoModulePublicAsset `
                -ModuleId $id `
                -PublicRoot $publicRoot `
                -Url $fragment `
                -AllowedExtensions @(".html")
        }
        if ($tabIds.Count -eq 0) {
            throw "Le dock du module $id ne declare aucun onglet."
        }
    }

    return $manifest
}

function Get-MiaoExportedModuleCommand {
    param(
        [Parameter(Mandatory = $true)]$Module,
        [AllowEmptyString()][string]$Name = "",
        [bool]$Required = $false
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        if ($Required) {
            throw "Hook de module obligatoire absent."
        }
        return $null
    }

    if (-not $Module.ExportedCommands.ContainsKey($Name)) {
        throw "Le module $($Module.Name) n'exporte pas le hook $Name."
    }

    return $Module.ExportedCommands[$Name]
}

function Get-MiaoModuleOptions {
    param($Options, [string]$Id)

    if ($Options -is [System.Collections.IDictionary] -and $Options.Contains($Id)) {
        return $Options[$Id]
    }
    return @{}
}

function Get-MiaoModuleDefinitions {
    param([string]$RootPath)

    $modulesPath = Join-Path $RootPath "modules"
    if (-not [System.IO.Directory]::Exists($modulesPath)) {
        return @()
    }

    $definitions = @()
    $claimedAliases = @{}
    $moduleDirectories = @(
        [System.IO.Directory]::GetDirectories($modulesPath) |
            Sort-Object { [System.IO.Path]::GetFileName($_) }
    )

    foreach ($modulePath in $moduleDirectories) {
        $manifestPath = Join-Path $modulePath "module.json"
        if (-not [System.IO.File]::Exists($manifestPath)) {
            continue
        }

        $manifest = Read-MiaoModuleManifest -Path $manifestPath
        if (-not [bool](Get-MiaoManifestValue $manifest "enabled" $true)) {
            continue
        }

        $publicDefinition = Get-MiaoManifestValue $manifest "public" $null
        foreach ($alias in @(
            Get-MiaoManifestValue $publicDefinition "aliases" @()
        )) {
            $route = [string]$alias.route
            if ($claimedAliases.ContainsKey($route)) {
                throw "Alias public partage par plusieurs modules : $route"
            }
            $claimedAliases[$route] = [string]$manifest.id
        }

        $publicRoot = $null
        if ($null -ne $publicDefinition) {
            $publicRoot = Resolve-MiaoContainedPath `
                -BasePath $modulePath `
                -ChildPath ([string]$publicDefinition.root)
        }

        $definitions += [pscustomobject]@{
            ModulePath = $modulePath
            Manifest = $manifest
            PublicRoot = $publicRoot
            EntryPath = Resolve-MiaoContainedPath `
                -BasePath $modulePath `
                -ChildPath ([string]$manifest.entry)
        }
    }

    return $definitions
}

function Import-MiaoApplicationModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)]$ApplicationContext,
        $Options = @{}
    )

    $loadedModules = @()
    try {
        foreach ($definition in @(Get-MiaoModuleDefinitions -RootPath $RootPath)) {
            $manifest = $definition.Manifest
            $importedModules = @(
                Import-Module $definition.EntryPath -PassThru -ErrorAction Stop
            )
            $importedModule = $importedModules |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.Path) -and
                    [System.IO.Path]::GetFullPath($_.Path) -eq $definition.EntryPath
                } |
                Select-Object -Last 1
            if ($null -eq $importedModule) {
                throw "Chargement du point d'entree impossible : $($definition.EntryPath)"
            }

            $hooks = $manifest.hooks
            $initializeCommand = Get-MiaoExportedModuleCommand `
                -Module $importedModule `
                -Name ([string]$hooks.initialize) `
                -Required $true
            $updateCommand = Get-MiaoExportedModuleCommand `
                -Module $importedModule `
                -Name ([string](Get-MiaoManifestValue $hooks "update" ""))
            $routeCommand = Get-MiaoExportedModuleCommand `
                -Module $importedModule `
                -Name ([string](Get-MiaoManifestValue $hooks "route" ""))
            $shutdownCommand = Get-MiaoExportedModuleCommand `
                -Module $importedModule `
                -Name ([string](Get-MiaoManifestValue $hooks "shutdown" ""))

            $moduleOptions = Get-MiaoModuleOptions `
                -Options $Options `
                -Id ([string]$manifest.id)
            $stateOutput = @(
                & $initializeCommand `
                    -ApplicationContext $ApplicationContext `
                    -ModulePath $definition.ModulePath `
                    -Options $moduleOptions
            )
            if ($stateOutput.Count -gt 1) {
                throw "Le module $($manifest.id) a retourne plusieurs etats."
            }
            $state = if ($stateOutput.Count -eq 1) {
                $stateOutput[0]
            }
            else {
                $null
            }

            $interval = [int](Get-MiaoManifestValue $manifest "updateIntervalMs" 1000)
            $loadedModules += [pscustomobject]@{
                Id = [string]$manifest.id
                Name = [string]$manifest.name
                Version = [string]$manifest.version
                Path = $definition.ModulePath
                PublicRoot = $definition.PublicRoot
                Manifest = $manifest
                State = $state
                UpdateCommand = $updateCommand
                RouteCommand = $routeCommand
                ShutdownCommand = $shutdownCommand
                UpdateIntervalMs = $interval
                NextUpdateUtc = [System.DateTime]::UtcNow
                LastUpdateError = ""
            }
        }
    }
    catch {
        $rollbackContext = [pscustomobject]@{ Modules = $loadedModules }
        Stop-MiaoApplicationModules -ApplicationContext $rollbackContext
        throw
    }

    return $loadedModules
}

function Update-MiaoApplicationModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$ApplicationContext
    )

    $now = [System.DateTime]::UtcNow
    foreach ($module in @($ApplicationContext.Modules)) {
        if ($null -eq $module.UpdateCommand -or $now -lt $module.NextUpdateUtc) {
            continue
        }

        $module.NextUpdateUtc = $now.AddMilliseconds($module.UpdateIntervalMs)
        try {
            $null = & $module.UpdateCommand -State $module.State -Now $now
            $module.LastUpdateError = ""
        }
        catch {
            $message = $_.Exception.Message
            if ($module.LastUpdateError -ne $message) {
                Write-Warning "Module $($module.Id) : $message"
                $module.LastUpdateError = $message
            }
        }
    }
}

function Stop-MiaoApplicationModules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$ApplicationContext
    )

    foreach ($module in @($ApplicationContext.Modules)) {
        if ($null -eq $module.ShutdownCommand) {
            continue
        }

        try {
            $null = & $module.ShutdownCommand -State $module.State
        }
        catch {
            Write-Warning "Arret incomplet du module $($module.Id) : $($_.Exception.Message)"
        }
    }
}

function Invoke-MiaoApplicationModuleRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Request,
        [Parameter(Mandatory = $true)]$ApplicationContext,
        [Parameter(Mandatory = $true)][System.Net.Sockets.TcpClient]$Client
    )

    foreach ($module in @($ApplicationContext.Modules)) {
        if ($null -eq $module.RouteCommand) {
            continue
        }

        $routeOutput = @(
            & $module.RouteCommand `
                -Request $Request `
                -State $module.State `
                -ApplicationContext $ApplicationContext `
                -Client $Client
        )
        if ($routeOutput.Count -gt 1) {
            throw "Le module $($module.Id) a retourne plusieurs resultats de route."
        }
        if ($routeOutput.Count -eq 1 -and [bool]$routeOutput[0]) {
            return $true
        }
    }

    return $false
}

function Resolve-MiaoModuleStaticRoute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RequestPath,
        [Parameter(Mandatory = $true)]$Modules
    )

    foreach ($module in @($Modules)) {
        $publicDefinition = Get-MiaoManifestValue $module.Manifest "public" $null
        if ($null -eq $publicDefinition -or $null -eq $module.PublicRoot) {
            continue
        }

        foreach ($alias in @(Get-MiaoManifestValue $publicDefinition "aliases" @())) {
            if ([string]$alias.route -eq $RequestPath) {
                $filePath = Resolve-MiaoContainedPath `
                    -BasePath $module.PublicRoot `
                    -ChildPath ([string]$alias.file)
                if (-not [System.IO.File]::Exists($filePath)) {
                    throw "Ressource publique de module introuvable : $filePath"
                }
                return [pscustomobject]@{
                    FilePath = $filePath
                    ContentType = Get-MiaoContentType -Path $filePath
                }
            }
        }

        $routePrefix = "/modules/$($module.Id)/"
        if (-not $RequestPath.StartsWith(
            $routePrefix,
            [System.StringComparison]::Ordinal
        )) {
            continue
        }

        try {
            $filePath = Get-MiaoModulePublicFilePath `
                -ModuleId $module.Id `
                -PublicRoot $module.PublicRoot `
                -Url $RequestPath
        }
        catch {
            return $null
        }
        if (-not [System.IO.File]::Exists($filePath)) {
            return $null
        }

        return [pscustomobject]@{
            FilePath = $filePath
            ContentType = Get-MiaoContentType -Path $filePath
        }
    }

    return $null
}

function Get-MiaoClientModuleDescriptors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Modules
    )

    $descriptors = @()
    foreach ($module in @($Modules)) {
        $control = Get-MiaoManifestValue $module.Manifest "control" $null
        if ($null -eq $control) {
            continue
        }

        $styles = @()
        foreach ($style in @(Get-MiaoManifestValue $control "styles" @())) {
            $styles += [string]$style
        }
        $scripts = @()
        foreach ($script in @(Get-MiaoManifestValue $control "scripts" @())) {
            $scripts += [string]$script
        }
        $tabs = @()
        foreach ($tab in @(Get-MiaoManifestValue $control "tabs" @())) {
            $tabs += [ordered]@{
                id = [string]$tab.id
                label = [string]$tab.label
                fragment = [string]$tab.fragment
            }
        }

        $descriptors += [ordered]@{
            id = $module.Id
            name = $module.Name
            version = $module.Version
            control = [ordered]@{
                styles = $styles
                scripts = $scripts
                tabs = $tabs
            }
        }
    }

    return $descriptors
}

Export-ModuleMember -Function `
    Read-MiaoModuleManifest, `
    Import-MiaoApplicationModules, `
    Update-MiaoApplicationModules, `
    Stop-MiaoApplicationModules, `
    Invoke-MiaoApplicationModuleRoute, `
    Resolve-MiaoModuleStaticRoute, `
    Get-MiaoClientModuleDescriptors
