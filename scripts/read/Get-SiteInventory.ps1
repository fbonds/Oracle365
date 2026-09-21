<#
.SYNOPSIS
    Enumerates site collections and their sharing and storage posture.

.DESCRIPTION
    The starting point for every governance question: what sites exist, who
    owns them, how they are shared, and which ones nobody has touched.

    Read-only. Nothing here changes tenant state.

    Requires delegated authentication as a SharePoint Administrator.
    Get-PnPTenantSite requires SharePoint Online administrator access, so
    an app registration holding only Sites.Selected cannot enumerate sites.
    Sites.Selected is per-site by design: it can inspect a site that has
    been granted, but it cannot discover one.

.PARAMETER AdminUrl
    SharePoint admin URL, for example https://contoso-admin.sharepoint.com

.PARAMETER IncludeOneDrive
    Include personal OneDrive sites. Off by default: in a tenant of any
    size they dominate the output and are rarely the governance question.

.PARAMETER DormantAfterDays
    A site with no content modification in this many days is flagged
    dormant. Defaults to 180. Dormant is a prompt to look, not a verdict.

.EXAMPLE
    ./Get-SiteInventory.ps1 -AdminUrl https://contoso-admin.sharepoint.com

.NOTES
    Cmdlet names and parameters verified against the PnP PowerShell
    documentation on the dev branch, 2026-09-21. Not yet run against a
    live tenant.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdminUrl,

    [switch]$IncludeOneDrive,

    [ValidateRange(1, 3650)]
    [int]$DormantAfterDays = 180,

    [ValidateSet('Delegated', 'AppOnly')]
    [string]$Mode = 'Delegated'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' 'lib' 'Oracle365.Common.ps1')

Connect-Oracle365 -Url $AdminUrl -Mode $Mode

Write-Host 'Enumerating site collections...'

$getArgs = @{ Detailed = $true }
if ($IncludeOneDrive) { $getArgs['IncludeOneDriveSites'] = $true }

try {
    $raw = Get-PnPTenantSite @getArgs
}
catch {
    Write-Error "Could not enumerate sites: $($_.Exception.Message)"
    Write-Host ''
    Write-Host 'Get-PnPTenantSite requires SharePoint Online administrator access.'
    Write-Host 'If you are connected app-only with Sites.Selected, this will always'
    Write-Host 'fail: that grant is per-site and cannot discover sites. Connect'
    Write-Host 'delegated as an administrator instead, with -Mode Delegated.'
    return
}

$cutoff = (Get-Date).AddDays(-$DormantAfterDays)

$sites = @($raw | ForEach-Object {
    $lastModified = $null
    # LastContentModifiedDate is not present on every template or tenant.
    if ($_.PSObject.Properties.Name -contains 'LastContentModifiedDate') {
        $lastModified = $_.LastContentModifiedDate
    }

    [ordered]@{
        url                = [string]$_.Url
        title              = [string]$_.Title
        template           = [string]$_.Template
        owner              = [string]$_.Owner
        sharing_capability = [string]$_.SharingCapability
        storage_used_mb    = $_.StorageUsageCurrent
        storage_quota_mb   = $_.StorageQuota
        lock_state         = [string]$_.LockState
        group_id           = [string]$_.GroupId
        last_modified      = if ($lastModified) { $lastModified.ToString('yyyy-MM-dd') } else { $null }
        dormant            = if ($lastModified) { $lastModified -lt $cutoff } else { $null }
    }
})

# --- Findings --------------------------------------------------------------
#
# A finding is a fact. Whether it is a violation depends on conventions.md,
# which this script does not read. Reporting is deliberately neutral.

$externalSharing = @($sites | Where-Object {
    $_.sharing_capability -in @('ExternalUserSharingOnly',
                                'ExternalUserAndGuestSharing',
                                'ExistingExternalUserSharingOnly')
})
$anonymousSharing = @($sites | Where-Object { $_.sharing_capability -eq 'ExternalUserAndGuestSharing' })
$dormant          = @($sites | Where-Object { $_.dormant -eq $true })
$noOwner          = @($sites | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) })
$locked           = @($sites | Where-Object { $_.lock_state -and $_.lock_state -ne 'Unlock' })

Write-Host ''
Write-Host ("Sites: {0}" -f $sites.Count)
Write-Host ''
Write-Host 'By template'
Write-Host '-----------'
$sites | Group-Object template | Sort-Object Count -Descending | ForEach-Object {
    Write-Host ("  {0,-28} {1}" -f $_.Name, $_.Count)
}

Write-Host ''
Write-Host 'Findings'
Write-Host '--------'
Write-Host ("  External sharing enabled     {0}" -f $externalSharing.Count)
Write-Host ("  Anonymous links permitted    {0}" -f $anonymousSharing.Count)
Write-Host ("  Dormant over {0,4} days       {1}" -f $DormantAfterDays, $dormant.Count)
Write-Host ("  No owner recorded            {0}" -f $noOwner.Count)
Write-Host ("  Locked or read-only          {0}" -f $locked.Count)
Write-Host ''
Write-Host 'These are facts, not violations. Whether any of them breaks a rule'
Write-Host 'depends on conventions.md, and a deliberate exception recorded in'
Write-Host 'profile.md is a decision rather than a finding.'

if ($anonymousSharing.Count -gt 0) {
    Write-Host ''
    Write-Host 'Sites permitting anonymous links:'
    $anonymousSharing | ForEach-Object { Write-Host ("  {0}" -f $_.url) }
}

if ($noOwner.Count -gt 0) {
    Write-Host ''
    Write-Host 'Sites with no owner recorded. An unowned site is the most common'
    Write-Host 'governance failure in a small organization, because nobody notices'
    Write-Host 'until access is needed:'
    $noOwner | ForEach-Object { Write-Host ("  {0}" -f $_.url) }
}

$snapshot = Write-Oracle365Snapshot `
    -Name 'site-inventory' `
    -Scope ("Site collections, OneDrive {0}" -f $(if ($IncludeOneDrive) { 'included' } else { 'excluded' })) `
    -Mode $Mode `
    -Data ([ordered]@{
        dormant_after_days = $DormantAfterDays
        site_count         = $sites.Count
        sites              = $sites
        summary            = [ordered]@{
            external_sharing  = $externalSharing.Count
            anonymous_sharing = $anonymousSharing.Count
            dormant           = $dormant.Count
            no_owner          = $noOwner.Count
            locked            = $locked.Count
        }
    })

Write-Host ''
Write-Host "Snapshot: $snapshot"
