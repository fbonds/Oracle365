<#
.SYNOPSIS
    First-run setup for Oracle365.

.DESCRIPTION
    Creates the Oracle365 configuration directory, copies templates into
    it, and optionally registers an Entra ID application with a
    certificate for app-only SharePoint access.

    Read this script before running it. It creates an app registration in
    your tenant, which is a real change requiring Global Administrator
    consent.

    Nothing secret is written to disk by this script. The certificate
    private key is created in the current user's certificate store by
    Register-PnPEntraIDApp and stays there.

    The app carries two sets of permissions, for two different jobs.

    Application permissions, used unattended: Sites.Selected on both the
    SharePoint and the Microsoft Graph APIs. Both are needed. PnP CSOM
    operations and Grant-PnPEntraIDAppSitePermission depend on the
    SharePoint one; Graph reads depend on the Graph one. Sites.Selected
    grants no access by itself, so after consent you grant the app access
    to individual sites with Grant-PnPEntraIDAppSitePermission.

    Delegated permissions, used interactively: AllSites.FullControl on
    SharePoint and LicenseAssignment.Read.All on Graph. Tenant-wide reads
    need these. Get-PnPTenantSite requires SharePoint Administrator and
    /subscribedSkus requires a licensing permission, neither of which
    Sites.Selected can provide. Delegated permissions are capped by the
    roles the signed-in person holds, so this creates no standing
    credential that can read the tenant unattended.

.PARAMETER Tenant
    Tenant domain, for example contoso.onmicrosoft.com. Without it, the
    app registration step is skipped.

.PARAMETER ApplicationName
    Name of the Entra ID application. Defaults to Oracle365. This name is
    also required by Grant-PnPEntraIDAppSitePermission -DisplayName, so
    changing it means using the new name there too.

.PARAMETER CertificateValidYears
    Certificate lifetime in years. Defaults to 2. Record the expiry
    somewhere you will see it: an expired certificate fails as an auth
    error that looks like a permissions problem.

.PARAMETER DeviceLogin
    Authenticate with device code instead of a browser window. Use this
    over SSH or anywhere a browser cannot open.

.PARAMETER SkipAppRegistration
    Create the config directory and copy templates only. Use this if an
    app registration already exists, or if you intend to create one by
    hand in the Entra portal.

.EXAMPLE
    ./Initialize-Oracle365.ps1 -Tenant contoso.onmicrosoft.com -WhatIf

    Shows what would happen without changing anything. Run this first.

.EXAMPLE
    ./Initialize-Oracle365.ps1 -Tenant contoso.onmicrosoft.com

.EXAMPLE
    ./Initialize-Oracle365.ps1 -SkipAppRegistration

    Config directory and templates only.

.NOTES
    Requires the PnP.PowerShell module and PowerShell 7 or later on
    Linux and macOS. Cmdlet names and parameters verified against the PnP
    PowerShell documentation on the dev branch, 2026-09-21.

    Not yet executed against a live tenant. Use -WhatIf first.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$Tenant,

    [Parameter(Mandatory = $false)]
    [string]$ApplicationName = 'Oracle365',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$CertificateValidYears = 2,

    [switch]$DeviceLogin,

    [switch]$SkipAppRegistration
)

$ErrorActionPreference = 'Stop'

function Get-Oracle365ConfigPath {
    if ($env:ORACLE365_CONFIG_DIR) { return $env:ORACLE365_CONFIG_DIR }
    if ($env:XDG_CONFIG_HOME)      { return (Join-Path $env:XDG_CONFIG_HOME 'oracle365') }
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        return (Join-Path $env:APPDATA 'Oracle365')
    }
    return (Join-Path $HOME '.config/oracle365')
}

function Get-Oracle365CachePath {
    if ($env:ORACLE365_CACHE_DIR) { return $env:ORACLE365_CACHE_DIR }
    if ($env:XDG_CACHE_HOME)      { return (Join-Path $env:XDG_CACHE_HOME 'oracle365') }
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        return (Join-Path $env:LOCALAPPDATA 'Oracle365')
    }
    return (Join-Path $HOME '.cache/oracle365')
}

$configPath = Get-Oracle365ConfigPath
$cachePath  = Get-Oracle365CachePath
$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$templates  = Join-Path $repoRoot 'templates'

Write-Host ''
Write-Host 'Oracle365 first-run setup'
Write-Host '-------------------------'
Write-Host "Config directory: $configPath"
Write-Host "Cache directory:  $cachePath"
Write-Host "Templates:        $templates"
Write-Host ''

if (-not (Test-Path $templates)) {
    throw "Templates directory not found at $templates. Run this from inside the repository."
}

# --- Config and cache directories -----------------------------------------

foreach ($dir in @($configPath, $cachePath)) {
    if (Test-Path $dir) {
        Write-Host "Exists: $dir"
    }
    elseif ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created: $dir"
    }
}

# Restrict permissions on POSIX. Windows inherits from the user profile.
if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    if ($PSCmdlet.ShouldProcess($configPath, 'Set permissions to 700')) {
        & chmod 700 $configPath
    }
}

# --- Templates -------------------------------------------------------------

$copies = @(
    @{ From = 'profile.example.md';     To = 'profile.md' }
    @{ From = 'conventions.example.md'; To = 'conventions.md' }
)

foreach ($c in $copies) {
    $src = Join-Path $templates $c.From
    $dst = Join-Path $configPath $c.To

    if (Test-Path $dst) {
        Write-Host "Exists, not overwriting: $dst"
        continue
    }
    if ($PSCmdlet.ShouldProcess($dst, "Copy from $($c.From)")) {
        Copy-Item $src $dst
        Write-Host "Created: $dst"
    }
}

# --- App registration ------------------------------------------------------

if ($SkipAppRegistration) {
    Write-Host ''
    Write-Host 'Skipping app registration as requested.'
}
else {
    if (-not $Tenant) {
        Write-Host ''
        Write-Host 'No -Tenant supplied, so skipping app registration.'
        Write-Host 'Re-run with -Tenant <yourtenant>.onmicrosoft.com to create one.'
    }
    elseif (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Warning 'PnP.PowerShell is not installed. Install it with:'
        Write-Warning '  Install-Module PnP.PowerShell -Scope CurrentUser'
        Write-Warning 'Then re-run this script.'
    }
    else {
        Write-Host ''
        Write-Host 'About to create an Entra ID app registration.'
        Write-Host ''
        Write-Host "  Tenant:      $Tenant"
        Write-Host "  Name:        $ApplicationName"
        Write-Host '  Certificate: self-signed, created in CurrentUser\My'
        Write-Host '  Application permissions (unattended, app-only):'
        Write-Host '    SharePoint:  Sites.Selected'
        Write-Host '    Graph:       Sites.Selected'
        Write-Host ''
        Write-Host '  Delegated permissions (interactive, as the signed-in user):'
        Write-Host '    SharePoint:  AllSites.FullControl'
        Write-Host '    Graph:       LicenseAssignment.Read.All, User.Read'
        Write-Host ''
        Write-Host 'Two identities, deliberately.'
        Write-Host ''
        Write-Host 'The application permissions are what runs unattended, so they are'
        Write-Host 'kept to Sites.Selected: per-site, granted one site at a time. Both'
        Write-Host 'APIs are needed. Grant-PnPEntraIDAppSitePermission and PnP CSOM'
        Write-Host 'depend on the SharePoint one; Graph reads depend on the Graph one.'
        Write-Host ''
        Write-Host 'The delegated permissions are what tenant-wide reads use. Site'
        Write-Host 'enumeration and licensing are impossible under Sites.Selected:'
        Write-Host 'Get-PnPTenantSite requires SharePoint Administrator, and'
        Write-Host '/subscribedSkus requires LicenseAssignment.Read.All. Delegated'
        Write-Host 'permissions are bounded by the roles the signed-in person actually'
        Write-Host 'holds, so they add no standing credential that could read the'
        Write-Host 'tenant on its own. Nothing runs unattended under them.'
        Write-Host ''
        Write-Host 'Sites.Selected grants no access on its own. After consent you must'
        Write-Host 'grant this app access to each site collection explicitly. That is'
        Write-Host 'the point. Do not widen it without recording why in profile.md.'
        Write-Host ''
        Write-Host 'Note: Register-PnPEntraIDApp defaults to Sites.FullControl.All,'
        Write-Host 'Group.ReadWrite.All and User.Read.All when no permissions are'
        Write-Host 'specified. This script always specifies them, so that default'
        Write-Host 'never applies here.'
        Write-Host ''
        Write-Host 'A Global Administrator must consent to the registration.'
        Write-Host ''

        if ($PSCmdlet.ShouldProcess($Tenant, "Register Entra ID application '$ApplicationName'")) {

            $registerArgs = @{
                ApplicationName                  = $ApplicationName
                Tenant                           = $Tenant
                Store                            = 'CurrentUser'
                SharePointApplicationPermissions = @('Sites.Selected')
                GraphApplicationPermissions      = @('Sites.Selected')
                SharePointDelegatePermissions    = @('AllSites.FullControl')
                GraphDelegatePermissions         = @('LicenseAssignment.Read.All', 'User.Read')
                ValidYears                       = $CertificateValidYears
            }
            if ($DeviceLogin) { $registerArgs['DeviceLogin'] = $true }

            try {
                $app = Register-PnPEntraIDApp @registerArgs
            }
            catch {
                Write-Host ''
                Write-Error "App registration failed: $($_.Exception.Message)"
                Write-Host ''
                Write-Host 'Common causes:'
                Write-Host '  - The signed-in account is not a Global Administrator.'
                Write-Host '  - Users are blocked from registering applications in this'
                Write-Host '    tenant. An administrator must either lift that or create'
                Write-Host '    the registration by hand.'
                Write-Host '  - An application with this name already exists. Re-run with'
                Write-Host '    -SkipAppRegistration, or pass a different -ApplicationName.'
                Write-Host ''
                Write-Host 'The config directory and templates were created regardless.'
                return
            }

            Write-Host ''
            Write-Host 'Registered. Full result follows. Record the application id and'
            Write-Host 'certificate thumbprint in profile.md.'
            Write-Host ''
            $app | Format-List | Out-String | Write-Host
            Write-Host 'None of the above is a secret. The private key stays in the'
            Write-Host 'certificate store and is not written to any file by this script.'
            Write-Host ''
            Write-Host 'Consent is not automatic. Confirm in the Entra portal that'
            Write-Host 'admin consent has been granted before relying on this app.'
        }
    }
}

# --- Next steps ------------------------------------------------------------

Write-Host ''
Write-Host 'Next steps'
Write-Host '----------'
Write-Host "1. Fill in $(Join-Path $configPath 'profile.md')"
Write-Host '   Start with license_tier. It gates what can be recommended.'
Write-Host "2. Fill in $(Join-Path $configPath 'conventions.md')"
Write-Host '   An empty section is honest. An invented one is not.'
Write-Host '3. Grant the app access to each site it needs, one at a time:'
Write-Host ''
Write-Host '     Grant-PnPEntraIDAppSitePermission `'
Write-Host "       -AppId <client_id> -DisplayName '$ApplicationName' ``"
Write-Host '       -Permissions Read -Site https://<tenant>.sharepoint.com/sites/<site>'
Write-Host ''
Write-Host '   -DisplayName must match the app registration name exactly.'
Write-Host '   Permissions are Read, Write, Manage or FullControl. Start at Read.'
Write-Host ''
Write-Host '4. Verify the connection:'
Write-Host ''
Write-Host '     Connect-PnPOnline -Url <site> -ClientId <client_id> `'
Write-Host "       -Tenant $Tenant -Thumbprint <thumbprint>"
Write-Host '     Get-PnPWeb'
Write-Host ''
Write-Host '5. Open the repository in your agent and ask it to check the profile.'
Write-Host ''
