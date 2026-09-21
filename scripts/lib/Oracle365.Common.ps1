<#
.SYNOPSIS
    Shared functions for Oracle365 scripts.

.DESCRIPTION
    Dot-source this from any Oracle365 script:

        . (Join-Path $PSScriptRoot '..' 'lib' 'Oracle365.Common.ps1')

    Provides configuration and cache path resolution, profile parsing,
    connection handling, and snapshot writing.

.NOTES
    Cmdlet names and parameters verified against the PnP PowerShell
    documentation on the dev branch, 2026-09-21.
#>

Set-StrictMode -Version Latest

function Test-Oracle365IsWindows {
    <#
        $IsWindows exists only in PowerShell 6+. On Windows PowerShell 5.1
        it is undefined, and 5.1 only runs on Windows, so absence plus a
        major version of 5 or lower means Windows.
    #>
    if ($null -ne (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue)) {
        return $IsWindows
    }
    return ($PSVersionTable.PSVersion.Major -le 5)
}

function Get-Oracle365ConfigPath {
    <#
    .SYNOPSIS
        Resolves the Oracle365 configuration directory.
    .DESCRIPTION
        Resolution order, first match wins:
          1. $env:ORACLE365_CONFIG_DIR
          2. $env:XDG_CONFIG_HOME/oracle365
          3. %APPDATA%\Oracle365 on Windows
          4. ~/.config/oracle365
        Matches the order documented in AGENTS.md.
    #>
    [CmdletBinding()]
    param()

    if ($env:ORACLE365_CONFIG_DIR) { return $env:ORACLE365_CONFIG_DIR }
    if ($env:XDG_CONFIG_HOME)      { return (Join-Path $env:XDG_CONFIG_HOME 'oracle365') }
    if (Test-Oracle365IsWindows)   { return (Join-Path $env:APPDATA 'Oracle365') }
    return (Join-Path $HOME '.config/oracle365')
}

function Get-Oracle365CachePath {
    <#
    .SYNOPSIS
        Resolves the Oracle365 cache directory for regenerable snapshots.
    #>
    [CmdletBinding()]
    param()

    if ($env:ORACLE365_CACHE_DIR) { return $env:ORACLE365_CACHE_DIR }
    if ($env:XDG_CACHE_HOME)      { return (Join-Path $env:XDG_CACHE_HOME 'oracle365') }
    if (Test-Oracle365IsWindows)  { return (Join-Path $env:LOCALAPPDATA 'Oracle365') }
    return (Join-Path $HOME '.cache/oracle365')
}

function Read-Oracle365Profile {
    <#
    .SYNOPSIS
        Reads profile.md and returns its scalar fields as a hashtable.
    .DESCRIPTION
        Parses lines of the form:

            - **key:** value

        Keys are lowercased. Values that are empty, or that consist only of
        a placeholder such as "unknown", are returned as $null so callers
        can test for them plainly.

        Tables in profile.md are not parsed. Read them yourself if needed.
    .OUTPUTS
        Hashtable. Empty if the file does not exist.
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Get-Oracle365ConfigPath)
    )

    $file = Join-Path $ConfigPath 'profile.md'
    $result = @{}

    if (-not (Test-Path $file)) {
        Write-Verbose "No profile at $file"
        return $result
    }

    foreach ($line in (Get-Content -LiteralPath $file)) {
        if ($line -match '^\s*-\s+\*\*(?<key>[^:*]+):\*\*\s*(?<value>.*?)\s*$') {
            $key   = $Matches['key'].Trim().ToLowerInvariant()
            $value = $Matches['value'].Trim()

            # Strip surrounding backticks used for formatting in the template.
            $value = $value -replace '^`+|`+$', ''

            if ([string]::IsNullOrWhiteSpace($value) -or $value -eq 'unknown') {
                $value = $null
            }
            $result[$key] = $value
        }
    }

    return $result
}

function Assert-Oracle365Profile {
    <#
    .SYNOPSIS
        Throws a useful error when required profile fields are missing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$TenantProfile,
        [Parameter(Mandatory)][string[]]$Required,
        [string]$ConfigPath = (Get-Oracle365ConfigPath)
    )

    $missing = @()
    foreach ($key in $Required) {
        if (-not $TenantProfile.ContainsKey($key) -or $null -eq $TenantProfile[$key]) {
            $missing += $key
        }
    }

    if ($missing.Count -gt 0) {
        throw ("Missing from profile.md: {0}`nEdit {1}" -f
            ($missing -join ', '),
            (Join-Path $ConfigPath 'profile.md'))
    }
}

function Connect-Oracle365 {
    <#
    .SYNOPSIS
        Connects PnP PowerShell using the identity recorded in profile.md.

    .DESCRIPTION
        Two modes.

        Delegated (default). Connects as the signed-in user with
        -Interactive. Everything is bounded by the roles that person
        actually holds, and nothing runs unattended. Use this for
        tenant-wide reads such as site inventory and licensing, which
        app-only Sites.Selected cannot do.

        AppOnly. Connects with the certificate recorded in profile.md.
        Use this for automation and for writes against granted sites.

        Since 9 September 2024, -Interactive requires a ClientId. It is
        read from profile.md, or from the ENTRAID_APP_ID or
        ENTRAID_CLIENT_ID environment variable if PnP finds one.

    .PARAMETER Url
        Site or tenant admin URL to connect to.

    .PARAMETER Mode
        Delegated or AppOnly. Defaults to Delegated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,

        [ValidateSet('Delegated', 'AppOnly')]
        [string]$Mode = 'Delegated',

        [hashtable]$TenantProfile = (Read-Oracle365Profile)
    )

    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        throw "PnP.PowerShell is not installed. Run: Install-Module PnP.PowerShell -Scope CurrentUser"
    }

    Assert-Oracle365Profile -TenantProfile $TenantProfile -Required @('client_id')

    switch ($Mode) {
        'AppOnly' {
            Assert-Oracle365Profile -TenantProfile $TenantProfile -Required @('tenant_id', 'certificate_thumbprint')

            Write-Verbose "Connecting app-only to $Url"
            Connect-PnPOnline -Url $Url `
                -ClientId   $TenantProfile['client_id'] `
                -Tenant     $TenantProfile['tenant_id'] `
                -Thumbprint $TenantProfile['certificate_thumbprint'] `
                -ValidateConnection
        }
        'Delegated' {
            Write-Verbose "Connecting interactively to $Url"
            Connect-PnPOnline -Url $Url `
                -ClientId $TenantProfile['client_id'] `
                -Interactive `
                -ValidateConnection
        }
    }
}

function Write-Oracle365Snapshot {
    <#
    .SYNOPSIS
        Writes a regenerable snapshot to the cache directory.

    .DESCRIPTION
        Snapshots go to the cache directory, never to the repository and
        never to the config directory. Each is stamped with the time it was
        generated, the scope it covers, and the identity that produced it,
        so a stale snapshot is visibly stale.

    .OUTPUTS
        The full path written.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Data,
        [Parameter(Mandatory)][string]$Scope,
        [string]$Mode = 'Delegated',
        [string]$CachePath = (Get-Oracle365CachePath)
    )

    if (-not (Test-Path $CachePath)) {
        if ($PSCmdlet.ShouldProcess($CachePath, 'Create cache directory')) {
            New-Item -ItemType Directory -Path $CachePath -Force | Out-Null
        }
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $file  = Join-Path $CachePath "$Name.json"

    $envelope = [ordered]@{
        generated_utc = $stamp
        scope         = $Scope
        auth_mode     = $Mode
        tool          = 'Oracle365'
        data          = $Data
    }

    if ($PSCmdlet.ShouldProcess($file, 'Write snapshot')) {
        $envelope | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $file -Encoding UTF8
        Write-Verbose "Wrote $file"
    }

    return $file
}

function Write-Oracle365ChangeLog {
    <#
    .SYNOPSIS
        Appends one line to changelog.md in the cache directory.
    .DESCRIPTION
        Required by the safety contract in AGENTS.md after every
        successful write against the tenant.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Rollback,
        [string]$CachePath = (Get-Oracle365CachePath)
    )

    if (-not (Test-Path $CachePath)) {
        if ($PSCmdlet.ShouldProcess($CachePath, 'Create cache directory')) {
            New-Item -ItemType Directory -Path $CachePath -Force | Out-Null
        }
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    if ([string]::IsNullOrWhiteSpace($Rollback)) {
        $Rollback = 'NO KNOWN ROLLBACK'
    }

    $line = "$stamp  $Operation  $Target  $Rollback"
    $file = Join-Path $CachePath 'changelog.md'

    if ($PSCmdlet.ShouldProcess($file, 'Append change log entry')) {
        Add-Content -LiteralPath $file -Value $line -Encoding UTF8
    }
}
