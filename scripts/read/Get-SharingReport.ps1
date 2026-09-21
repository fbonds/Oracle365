<#
.SYNOPSIS
    Reports external sharing posture across the tenant.

.DESCRIPTION
    Who outside the organization can reach SharePoint content, and through
    what. At Business Basic and Business Standard this is the main external
    access control available, so it carries more weight than it would in a
    tenant with Conditional Access and sensitivity labels.

    Read-only. Nothing here changes tenant state.

    Covers three levels:

      Tenant     The ceiling. No site can exceed it.
      Site       Each site's setting, which can be tighter than the tenant.
      People     External users who actually hold access.

    What it does not cover: individual sharing links on individual files.
    Enumerating those means walking every file in every library, which is
    infeasible above a few hundred documents and will be throttled. When
    you need it for a specific library, Get-PnPFileSharingLink and
    Get-PnPFolderSharingLink do it per item.

    One thing people get wrong: tightening a policy does not necessarily
    revoke links already issued under the old one. Treat existing links as
    outstanding until verified, not as retroactively cancelled.

.PARAMETER AdminUrl
    SharePoint admin URL, for example https://contoso-admin.sharepoint.com

.PARAMETER FromInventory
    Use the cached site-inventory snapshot for per-site settings rather
    than re-reading them. Faster, and stale by however old the snapshot is.

.EXAMPLE
    ./Get-SharingReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com

.NOTES
    Cmdlet names and parameters verified against the PnP PowerShell
    documentation on the dev branch, 2026-09-21. Not yet run against a
    live tenant.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,

    [switch]$FromInventory,

    [ValidateSet('Delegated', 'AppOnly')]
    [string]$Mode = 'Delegated'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' 'lib' 'Oracle365.Common.ps1')

Connect-Oracle365 -Url $AdminUrl -Mode $Mode

# --- Tenant ceiling --------------------------------------------------------

Write-Host 'Reading tenant sharing settings...'

$tenant = $null
try {
    $t = Get-PnPTenant
    $tenant = [ordered]@{
        sharing_capability                  = [string]$t.SharingCapability
        default_sharing_link_type           = [string]$t.DefaultSharingLinkType
        default_link_permission             = [string]$t.DefaultLinkPermission
        anonymous_link_expiry_days          = [string]$t.RequireAnonymousLinksExpireInDays
        prevent_external_resharing          = [string]$t.PreventExternalUsersFromResharing
        external_user_expiration_required   = [string]$t.ExternalUserExpirationRequired
        sharing_domain_restriction_mode     = [string]$t.SharingDomainRestrictionMode
        allowed_domain_list                 = [string]$t.SharingAllowedDomainList
        blocked_domain_list                 = [string]$t.SharingBlockedDomainList
    }
}
catch {
    Write-Warning "Could not read tenant settings: $($_.Exception.Message)"
    Write-Warning 'Get-PnPTenant requires SharePoint Administrator.'
}

# --- Per-site settings -----------------------------------------------------

$sites = @()
if ($FromInventory) {
    $snapshot = Read-Oracle365Snapshot -Name 'site-inventory'
    if ($snapshot) {
        $sites = @($snapshot.data.sites | ForEach-Object {
            [ordered]@{
                url                = [string]$_.url
                title              = [string]$_.title
                sharing_capability = [string]$_.sharing_capability
            }
        })
        Write-Host ("Using {0} sites from the inventory snapshot." -f $sites.Count)
    }
    else {
        Write-Warning 'No site-inventory snapshot. Reading sites live instead.'
    }
}

if ($sites.Count -eq 0) {
    Write-Host 'Reading site collections...'
    try {
        $sites = @(Get-PnPTenantSite | ForEach-Object {
            [ordered]@{
                url                = [string]$_.Url
                title              = [string]$_.Title
                sharing_capability = [string]$_.SharingCapability
            }
        })
    }
    catch {
        Write-Error "Could not enumerate sites: $($_.Exception.Message)"
        Write-Host 'Get-PnPTenantSite requires SharePoint Online administrator access.'
        return
    }
}

# --- External users --------------------------------------------------------

Write-Host 'Reading external users...'

$externalUsers = @()
try {
    $page = 0
    $maxPages = 200   # 10,000 users. A guard against a paging loop that never ends.
    do {
        $batch = @(Get-PnPExternalUser -Position ($page * 50) -PageSize 50)
        $externalUsers += $batch | ForEach-Object {
            [ordered]@{
                display_name    = [string]$_.DisplayName
                email           = [string]$_.Email
                accepted_as     = [string]$_.AcceptedAs
                invited_by      = [string]$_.InvitedBy
                when_created    = if ($_.WhenCreated) { $_.WhenCreated.ToString('yyyy-MM-dd') } else { $null }
            }
        }
        $page++
    } while ($batch.Count -eq 50 -and $page -lt $maxPages)

    if ($page -ge $maxPages) {
        Write-Warning "Stopped after $maxPages pages. There may be more external users."
    }
}
catch {
    Write-Warning "Could not read external users: $($_.Exception.Message)"
}

# --- Classification --------------------------------------------------------
#
# SharingCapability values, from most to least permissive:
#   ExternalUserAndGuestSharing       anonymous links permitted
#   ExternalUserSharingOnly           authenticated guests only
#   ExistingExternalUserSharingOnly   only guests already in the directory
#   Disabled                          internal only

$anonymous = @($sites | Where-Object { $_.sharing_capability -eq 'ExternalUserAndGuestSharing' })
$guests    = @($sites | Where-Object { $_.sharing_capability -eq 'ExternalUserSharingOnly' })
$existing  = @($sites | Where-Object { $_.sharing_capability -eq 'ExistingExternalUserSharingOnly' })
$internal  = @($sites | Where-Object { $_.sharing_capability -eq 'Disabled' })

# A site tighter than the tenant is deliberate. A site at the tenant ceiling
# may just be the default nobody changed. The distinction matters.
$atCeiling = @()
if ($tenant -and $tenant.sharing_capability) {
    $atCeiling = @($sites | Where-Object { $_.sharing_capability -eq $tenant.sharing_capability })
}

# --- Report ----------------------------------------------------------------

Write-Host ''
Write-Host 'Tenant ceiling'
Write-Host '--------------'
if ($tenant) {
    foreach ($k in $tenant.Keys) {
        Write-Host ("  {0,-36} {1}" -f $k, $tenant[$k])
    }
    Write-Host ''
    Write-Host 'No site can be more permissive than the tenant setting. Tightening'
    Write-Host 'it affects every site at once, which is rarely what people expect.'
}
else {
    Write-Host '  Not read. See the warning above.'
}

Write-Host ''
Write-Host ("Sites: {0}" -f $sites.Count)
Write-Host '-------------'
Write-Host ("  Anonymous links permitted        {0}" -f $anonymous.Count)
Write-Host ("  Authenticated guests only        {0}" -f $guests.Count)
Write-Host ("  Existing guests only             {0}" -f $existing.Count)
Write-Host ("  Internal only                    {0}" -f $internal.Count)
Write-Host ("  At the tenant ceiling            {0}" -f $atCeiling.Count)
Write-Host ''
Write-Host 'A site tighter than the tenant was set deliberately. A site at the'
Write-Host 'ceiling may just be the default nobody changed. Only the first tells'
Write-Host 'you somebody made a decision.'

if ($anonymous.Count -gt 0) {
    Write-Host ''
    Write-Host 'Sites permitting anonymous links. Anyone holding the URL reaches the'
    Write-Host 'content, with no sign-in and no audit trail of who:'
    $anonymous | ForEach-Object { Write-Host ("  {0}" -f $_.url) }
}

Write-Host ''
Write-Host ("External users: {0}" -f $externalUsers.Count)
Write-Host '---------------'
if ($externalUsers.Count -gt 0) {
    $externalUsers | Select-Object -First 25 | ForEach-Object {
        Write-Host ("  {0,-38} {1}" -f $_.email, $_.when_created)
    }
    if ($externalUsers.Count -gt 25) {
        Write-Host ("  ... and {0} more. Full list in the snapshot." -f ($externalUsers.Count - 25))
    }
    Write-Host ''
    Write-Host 'Each of these holds standing access. Without access reviews, which'
    Write-Host 'need Entra ID P2, the only way they get removed is somebody looking.'
}
else {
    Write-Host '  None found.'
}

$snapshotPath = Write-Oracle365Snapshot `
    -Name 'sharing-report' `
    -Scope 'Tenant and per-site sharing settings, external users' `
    -Mode $Mode `
    -Data ([ordered]@{
        tenant         = $tenant
        sites          = $sites
        external_users = $externalUsers
        summary        = [ordered]@{
            site_count       = $sites.Count
            anonymous        = $anonymous.Count
            guests_only      = $guests.Count
            existing_only    = $existing.Count
            internal_only    = $internal.Count
            at_ceiling       = $atCeiling.Count
            external_users   = $externalUsers.Count
        }
    })

Write-Host ''
Write-Host "Snapshot: $snapshotPath"
Write-Host ''
Write-Host 'Per-file sharing links are not covered here. Enumerating them means'
Write-Host 'walking every file in every library and will be throttled. For a'
Write-Host 'specific library, use Get-PnPFileSharingLink and'
Write-Host 'Get-PnPFolderSharingLink.'
