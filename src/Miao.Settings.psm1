Set-StrictMode -Version 2.0

Import-Module (Join-Path $PSScriptRoot "Miao.Files.psm1") -Force

function Import-MiaoSettingsSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $schema = Read-MiaoUtf8File -Path $Path | ConvertFrom-Json
    if ($null -eq $schema -or $null -eq $schema.groups) {
        throw "Le schema des reglages est invalide."
    }

    return $schema
}

function Get-MiaoSchemaFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Schema
    )

    $fields = @()
    foreach ($group in $Schema.groups) {
        foreach ($field in $group.fields) {
            $fields += $field
        }
    }

    return $fields
}

function Get-MiaoObjectValue {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Fallback
    )

    if ($null -eq $InputObject) {
        return $Fallback
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $Fallback
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $Fallback
    }

    return $property.Value
}

function ConvertTo-MiaoBoolean {
    param($Value, [bool]$Fallback)

    if ($Value -is [bool]) {
        return $Value
    }

    $parsed = $false
    if ([bool]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed
    }

    return $Fallback
}

function ConvertTo-MiaoInteger {
    param($Value, [int]$Fallback, [int]$Minimum, [int]$Maximum)

    $parsed = 0
    if (-not [int]::TryParse([string]$Value, [ref]$parsed)) {
        $parsed = $Fallback
    }
    return [System.Math]::Max($Minimum, [System.Math]::Min($Maximum, $parsed))
}

function ConvertTo-MiaoNumber {
    param($Value, [double]$Fallback, [double]$Minimum, [double]$Maximum)

    try {
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
            throw "Valeur numerique vide."
        }
        $parsed = [System.Convert]::ToDouble(
            $Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        if ([double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) {
            throw "Valeur numerique non finie."
        }
    }
    catch {
        $parsed = $Fallback
    }

    return [System.Math]::Max($Minimum, [System.Math]::Min($Maximum, $parsed))
}

function ConvertTo-MiaoString {
    param($Value, [string]$Fallback, [int]$MaximumLength, [bool]$Required)

    $text = [regex]::Replace([string]$Value, '[\x00\r\n]+', ' ').Trim()
    if ($Required -and [string]::IsNullOrWhiteSpace($text)) {
        $text = $Fallback
    }
    if ($text.Length -gt $MaximumLength) {
        $text = $text.Substring(0, $MaximumLength).TrimEnd()
    }

    return $text
}

function ConvertTo-MiaoFieldValue {
    param($Value, $Field)

    $type = [string]$Field.type
    $fallback = $Field.default

    switch ($type) {
        "boolean" {
            return ConvertTo-MiaoBoolean -Value $Value -Fallback ([bool]$fallback)
        }
        "integer" {
            return ConvertTo-MiaoInteger `
                -Value $Value `
                -Fallback ([int]$fallback) `
                -Minimum ([int]$Field.minimum) `
                -Maximum ([int]$Field.maximum)
        }
        "number" {
            return ConvertTo-MiaoNumber `
                -Value $Value `
                -Fallback ([double]$fallback) `
                -Minimum ([double]$Field.minimum) `
                -Maximum ([double]$Field.maximum)
        }
        "color" {
            $color = [string]$Value
            if ($color -match '^#[0-9a-fA-F]{6}$') {
                return $color.ToLowerInvariant()
            }
            return [string]$fallback
        }
        "select" {
            $choice = [string]$Value
            $allowed = @($Field.options | ForEach-Object { [string]$_.value })
            if ($allowed -contains $choice) {
                return $choice
            }
            return [string]$fallback
        }
        "string" {
            $maximumLength = [int](Get-MiaoObjectValue `
                -InputObject $Field `
                -Name "maximumLength" `
                -Fallback 200)
            $required = [bool](Get-MiaoObjectValue `
                -InputObject $Field `
                -Name "required" `
                -Fallback $false)
            return ConvertTo-MiaoString `
                -Value $Value `
                -Fallback ([string]$fallback) `
                -MaximumLength $maximumLength `
                -Required $required
        }
        default {
            throw "Type de reglage inconnu : $type"
        }
    }
}

function Get-MiaoDefaultSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Schema
    )

    $defaults = [ordered]@{
        version = [int]$Schema.version
    }

    foreach ($field in Get-MiaoSchemaFields -Schema $Schema) {
        $key = [string]$field.key
        $defaults[$key] = $field.default
    }

    return $defaults
}

function ConvertTo-MiaoSettings {
    [CmdletBinding()]
    param(
        [AllowNull()]$InputObject,

        [Parameter(Mandatory = $true)]
        $Schema
    )

    $settings = [ordered]@{
        version = [int]$Schema.version
    }

    foreach ($field in Get-MiaoSchemaFields -Schema $Schema) {
        $key = [string]$field.key
        $value = Get-MiaoObjectValue -InputObject $InputObject -Name $key -Fallback $field.default
        $settings[$key] = ConvertTo-MiaoFieldValue -Value $value -Field $field
    }

    foreach ($field in Get-MiaoSchemaFields -Schema $Schema) {
        $minimumFrom = [string](Get-MiaoObjectValue `
            -InputObject $field `
            -Name "minimumFrom" `
            -Fallback "")
        if (-not [string]::IsNullOrWhiteSpace($minimumFrom) -and
            $settings.Contains($minimumFrom) -and
            [double]($settings[[string]$field.key]) -lt [double]($settings[$minimumFrom])) {
            $settings[[string]$field.key] = $settings[$minimumFrom]
        }
    }

    return $settings
}

function Save-MiaoSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Settings,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $json = $Settings | ConvertTo-Json -Depth 8
    Write-MiaoUtf8FileAtomic -Path $Path -Content $json
}

function Backup-MiaoSettingsFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Suffix
    )

    $backupPath = "$Path.$Suffix.bak"
    if (-not [System.IO.File]::Exists($backupPath)) {
        [System.IO.File]::Copy($Path, $backupPath, $false)
    }
    return $backupPath
}

function Read-MiaoSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Schema
    )

    $source = $null
    $sourceWasRead = $false
    if ([System.IO.File]::Exists($Path)) {
        try {
            $source = Read-MiaoUtf8File -Path $Path | ConvertFrom-Json
            $sourceWasRead = $true
        }
        catch {
            $timestamp = [System.DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
            $backupPath = Backup-MiaoSettingsFile `
                -Path $Path `
                -Suffix "invalid-$timestamp"
            Write-Warning "Reglages invalides sauvegardes dans : $backupPath"
            $source = $null
        }
    }

    if ($sourceWasRead) {
        $sourceVersion = [string](Get-MiaoObjectValue `
            -InputObject $source `
            -Name "version" `
            -Fallback "legacy")
        $targetVersion = [string]$Schema.version
        if ($sourceVersion -ne $targetVersion) {
            $safeVersion = [regex]::Replace($sourceVersion, '[^A-Za-z0-9._-]', '_')
            [void](Backup-MiaoSettingsFile `
                -Path $Path `
                -Suffix "v$safeVersion")
        }
    }

    $settings = ConvertTo-MiaoSettings -InputObject $source -Schema $Schema
    Save-MiaoSettings -Settings $settings -Path $Path
    return $settings
}

Export-ModuleMember -Function `
    Import-MiaoSettingsSchema, `
    Get-MiaoSchemaFields, `
    Get-MiaoDefaultSettings, `
    ConvertTo-MiaoSettings, `
    Save-MiaoSettings, `
    Read-MiaoSettings
