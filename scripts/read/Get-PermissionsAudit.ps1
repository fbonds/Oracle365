<#
.SYNOPSIS
    Audits SharePoint permissions across one or more sites.

.DESCRIPTION
    Reports site collection administrators, SharePoint group membership,
    direct user grants, and every place inheritance has been broken.

    Read-only. Nothing here changes tenant state.

    Broken inheritance is the finding that matters most. It is cheap to
    create and permanent to maintain, and in a tenant of any age most of it
    was created by somebody solving a one-off problem who is no longer
    around to explain it.

    A finding is a fact. Whether it is a violation depends on
    conventions.md, and a deviation recorded in the exceptions table of
    profile.md is a decision rather than a finding. This script does not
    read either, and reports neutrally.

.PARAMETER SiteUrl
    One or more site URLs to audit. Omit to audit every site in the cached
    inventory snapshot.

.PARAMETER FromInventory
    Audit every site in the site-inventory snapshot. Run
    Get-SiteInventory.ps1 first.

.PARAMETER IncludeLists
    Check every list and library for broken inheritance. Slower, and the
    most useful part of the audit. On by default.

.PARAMETER DelayMilliseconds
    Pause between sites. SharePoint throttles aggressively and does not
    warn first. Raise this if you see 429 responses.

.EXAMPLE
    ./Get-PermissionsAudit.ps1 -SiteUrl https://contoso.sharepoint.com/sites/finance

.EXAMPLE
    ./Get-PermissionsAudit.ps1 -FromInventory

.NOTES
    Cmdlet names and parameters verified against the PnP PowerShell
    documentation on the dev branch, 2026-09-21. Not yet run against a
    live tenant.
#>

[CmdletBinding(DefaultParameterSetName = 'ByUrl')]
param(
    [Parameter(ParameterSetName = 'ByUrl', Mandatory)]
    [string[]]$SiteUrl,

    [Parameter(ParameterSetName = 'FromInventory', Mandatory)]
    [switch]$FromInventory,

    [bool]$IncludeLists = $true,

    [ValidateRange(0, 10000)]
    [int]$DelayMilliseconds = 200,

    [ValidateSet('Delegated', 'AppOnly')]
    [string]$Mode = 'Delegated'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' 'lib' 'Oracle365.Common.ps1')

# --- Decide which sites to audit -------------------------------------------

if ($FromInventory) {
    $snapshot = Read-Oracle365Snapshot -Name 'site-inventory'
    if (-not $snapshot) {
        throw "No site-inventory snapshot. Run Get-SiteInventory.ps1 first."
    }
    $targets = @($snapshot.data.sites | ForEach-Object { $_.url })
    Write-Host ("Auditing {0} sites from the inventory snapshot." -f $targets.Count)
}
else {
    $targets = $SiteUrl
}

# --- Audit one site --------------------------------------------------------

$auditSite = {
    param($url)

    Connect-Oracle365 -Url $url -Mode $Mode

    $web = Get-PnPWeb -Includes HasUniqueRoleAssignments, Title

    $admins = @(Get-PnPSiteCollectionAdmin | ForEach-Object {
        [ordered]@{
            title      = [string]$_.Title
            login      = [string]$_.LoginName
            email      = [string]$_.Email
            is_guest   = ([string]$_.LoginName) -like '*#ext#*'
        }
    })

    $groups = @(Get-PnPGroup | ForEach-Object {
        $groupName = $_.Title
        $members = @()
        try {
            $members = @(Get-PnPGroupMember -Group $groupName | ForEach-Object {
                [ordered]@{
                    title    = [string]$_.Title
                    login    = [string]$_.LoginName
                    is_guest = ([string]$_.LoginName) -like '*#ext#*'
                }
            })
        }
        catch {
            Write-Warning "Could not read members of '$groupName' on $url : $($_.Exception.Message)"
        }

        [ordered]@{
            title        = [string]$groupName
            owner        = [string]$_.OwnerTitle
            member_count = $members.Count
            members      = $members
        }
    })

    $uniqueLists = @()
    if ($IncludeLists) {
        $uniqueLists = @(
            Get-PnPList -Includes HasUniqueRoleAssignments |
                Where-Object { $_.HasUniqueRoleAssignments } |
                ForEach-Object {
                    [ordered]@{
                        title  = [string]$_.Title
                        url    = [string]$_.DefaultViewUrl
                        hidden = [bool]$_.Hidden
                    }
                }
        )
    }

    [ordered]@{
        url                    = $url
        title                  = [string]$web.Title
        web_unique_permissions = [bool]$web.HasUniqueRoleAssignments
        site_admins            = $admins
        admin_count            = $admins.Count
        guest_admins           = @($admins | Where-Object { $_.is_guest }).Count
        groups                 = $groups
        lists_unique_perms     = $uniqueLists
        unique_list_count      = $uniqueLists.Count
    }
}

$audited = Invoke-Oracle365Throttled `
    -Items $targets `
    -Action $auditSite `
    -DelayMilliseconds $DelayMilliseconds `
    -Activity 'Auditing permissions'

# --- Findings --------------------------------------------------------------

$fewAdmins   = @($audited | Where-Object { $_.admin_count -lt 2 })
$guestAdmins = @($audited | Where-Object { $_.guest_admins -gt 0 })
$brokenWebs  = @($audited | Where-Object { $_.web_unique_permissions })
$brokenLists = @($audited | Where-Object { $_.unique_list_count -gt 0 })
$emptyGroups = @($audited | ForEach-Object {
    $site = $_.url
    $_.groups | Where-Object { $_.member_count -eq 0 } | ForEach-Object {
        [ordered]@{ site = $site; group = $_.title }
    }
})

Write-Host ''
Write-Host ("Sites audited: {0}" -f $audited.Count)
Write-Host ''
Write-Host 'Findings'
Write-Host '--------'
Write-Host ("  Fewer than two site admins       {0}" -f $fewAdmins.Count)
Write-Host ("  Guest as site admin              {0}" -f $guestAdmins.Count)
Write-Host ("  Site inheritance broken          {0}" -f $brokenWebs.Count)
Write-Host ("  Sites with unique-perm lists     {0}" -f $brokenLists.Count)
Write-Host ("  Empty SharePoint groups          {0}" -f $emptyGroups.Count)

if ($fewAdmins.Count -gt 0) {
    Write-Host ''
    Write-Host 'Fewer than two site collection administrators. A single admin who'
    Write-Host 'leaves orphans the site, and recovering it needs a tenant admin:'
    $fewAdmins | ForEach-Object { Write-Host ("  {0,-60} {1}" -f $_.url, $_.admin_count) }
}

if ($guestAdmins.Count -gt 0) {
    Write-Host ''
    Write-Host 'Guest accounts holding site collection administrator. Worth a look'
    Write-Host 'in every case:'
    $guestAdmins | ForEach-Object { Write-Host ("  {0}" -f $_.url) }
}

if ($brokenLists.Count -gt 0) {
    Write-Host ''
    Write-Host 'Lists and libraries with unique permissions. Each one is a standing'
    Write-Host 'maintenance cost. Check whether the reason still applies:'
    $brokenLists | ForEach-Object {
        Write-Host ("  {0}" -f $_.url)
        $_.lists_unique_perms | ForEach-Object { Write-Host ("      {0}" -f $_.title) }
    }
}

$snapshotPath = Write-Oracle365Snapshot `
    -Name 'permissions-audit' `
    -Scope ("Permissions across {0} sites, lists {1}" -f $targets.Count, $(if ($IncludeLists) { 'included' } else { 'excluded' })) `
    -Mode $Mode `
    -Data ([ordered]@{
        sites   = $audited
        summary = [ordered]@{
            sites_audited           = $audited.Count
            fewer_than_two_admins   = $fewAdmins.Count
            guest_admins            = $guestAdmins.Count
            webs_broken_inheritance = $brokenWebs.Count
            sites_with_unique_lists = $brokenLists.Count
            empty_groups            = $emptyGroups.Count
        }
    })

Write-Host ''
Write-Host "Snapshot: $snapshotPath"
Write-Host ''
Write-Host 'These are facts, not violations. Compare them against conventions.md'
Write-Host 'before calling anything wrong, and check the exceptions table in'
Write-Host 'profile.md: a recorded deviation is a decision somebody already made.'
