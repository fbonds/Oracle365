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

.PARAMETER Tenant
    Tenant domain, for example contoso.onmicrosoft.com

.PARAMETER SkipAppRegistration
    Create the config directory and copy templates only. Use this if an
    app registration already exists, or if you intend to create one by
    hand in the Entra portal.

.EXAMPLE
    ./Initialize-Oracle365.ps1 -Tenant contoso.onmicrosoft.com -WhatIf

.NOTES
    Requires the PnP.PowerShell module.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$Tenant,

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
        Write-Host '  Name:        Oracle365'
        Write-Host '  Certificate: self-signed, created in CurrentUser\My'
        Write-Host '  Permission:  Sites.Selected (application)'
        Write-Host ''
        Write-Host 'Sites.Selected grants no access on its own. After consent you'
        Write-Host 'must grant this app access to each site collection explicitly.'
        Write-Host 'This is deliberate. Do not widen it without recording why.'
        Write-Host ''
        Write-Host 'A Global Administrator must consent to the registration.'
        Write-Host ''

        if ($PSCmdlet.ShouldProcess($Tenant, 'Register Entra ID application "Oracle365"')) {
            $app = Register-PnPEntraIDApp `
                -ApplicationName 'Oracle365' `
                -Tenant $Tenant `
                -GraphApplicationPermissions 'Sites.Selected' `
                -Store CurrentUser `
                -Interactive

            Write-Host ''
            Write-Host 'Registered. Record these in profile.md:'
            Write-Host ''
            Write-Host "  client_id:              $($app.'AzureAppId/ClientId')"
            Write-Host "  certificate_thumbprint: $($app.'Certificate Thumbprint')"
            Write-Host '  certificate_location:   CurrentUser\My'
            Write-Host ''
            Write-Host 'None of the above is a secret. The private key stays in the'
            Write-Host 'certificate store and is not written to any file by this script.'
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
Write-Host '3. Grant the app access to specific sites with Grant-PnPAzureADAppSitePermission.'
Write-Host '4. Open the repository in your agent and ask it to verify the connection.'
Write-Host ''
