# Read recipes

Verified commands for questions that actually get asked. Reads run freely,
so reach for these instead of asking someone to describe what you could
look at.

Verified against PnP PowerShell documentation, dev branch, 2026-09-21.

For anything covering more than one site, use the scripts in
`scripts/read/` rather than these one-liners. They handle paging,
throttling, and snapshot stamping.

## Connect first

Tenant-wide questions need the admin URL and delegated auth. Site
questions need that site's URL. See `connection-patterns.md`.

## "Why can't this person see this library?"

The most common question. Work down; stop when you find it.

```powershell
# 1. Is the library inheriting?
Get-PnPList -Identity "Documents" -Includes HasUniqueRoleAssignments |
  Select-Object Title, HasUniqueRoleAssignments

# 2. Is the site itself inheriting?
Get-PnPWeb -Includes HasUniqueRoleAssignments |
  Select-Object Title, HasUniqueRoleAssignments

# 3. Is the person in the group they should be in?
Get-PnPGroup | ForEach-Object {
    $g = $_.Title
    Get-PnPGroupMember -Group $g |
      Where-Object { $_.Email -eq 'person@contoso.org' } |
      Select-Object @{n='Group';e={$g}}, Title, LoginName
}

# 4. Is the user in the site at all?
Get-PnPUser | Where-Object { $_.Email -eq 'person@contoso.org' }

# 5. What does the library actually grant this principal?
#    PrincipalId comes from step 3 or 4.
Get-PnPWebPermission -Identity <web> -PrincipalId <id>
```

Check actual membership, not intended membership. The gap between the two
is the answer most of the time.

Group membership changes take time to propagate. If membership looks
correct and access is still denied, find out how recently it changed
before concluding the membership is wrong.

## "Where has inheritance been broken?"

```powershell
Get-PnPList -Includes HasUniqueRoleAssignments |
  Where-Object { $_.HasUniqueRoleAssignments } |
  Select-Object Title, DefaultViewUrl, Hidden
```

`Get-PnPWebPermission` needs a `-PrincipalId` and cannot enumerate, so
`-Includes HasUniqueRoleAssignments` is how you find breaks.

Include hidden lists. SharePoint creates plenty, and a unique-permission
hidden list is occasionally the explanation for something strange.

## "Who administers this site?"

```powershell
Get-PnPSiteCollectionAdmin |
  Select-Object Title, LoginName, Email
```

Fewer than two is a finding. A guest holding it is worth a look in every
case. Guests show as `#ext#` in `LoginName`.

## "Who outside the organization has access?"

```powershell
# Tenant-wide. Needs the admin URL.
Get-PnPExternalUser -PageSize 50

# Scoped to one site.
Get-PnPExternalUser -SiteUrl https://contoso.sharepoint.com/sites/finance
```

Page it. The cmdlet takes `-Position` and `-PageSize`, and the default
returns a first page rather than everything.

## "What is this site's sharing setting?"

```powershell
# One site, from the admin connection.
Get-PnPTenantSite -Identity https://contoso.sharepoint.com/sites/finance -Detailed |
  Select-Object Url, SharingCapability, DefaultSharingLinkType, DefaultLinkPermission

# The tenant ceiling. No site can exceed it.
Get-PnPTenant |
  Select-Object SharingCapability, DefaultSharingLinkType, DefaultLinkPermission
```

Values, most to least permissive: `ExternalUserAndGuestSharing` (anonymous
links), `ExternalUserSharingOnly` (authenticated guests),
`ExistingExternalUserSharingOnly` (guests already in the directory),
`Disabled`.

A site tighter than the tenant was set deliberately. A site at the ceiling
may be a default nobody touched.

## "What sharing links exist on this file?"

```powershell
Get-PnPFileSharingLink -Identity "/sites/finance/Shared Documents/budget.xlsx"
Get-PnPFolderSharingLink -Folder "Shared Documents/Board"
```

Per item only. There is no tenant-wide link enumeration that finishes in
reasonable time, so do not attempt one across a whole library.

## "Is this list about to hit the threshold?"

```powershell
Get-PnPList | Select-Object Title, ItemCount, EnableVersioning |
  Sort-Object ItemCount -Descending
```

The 5,000 limit is per view, not per list. A list with 40,000 items is
fine if every view filters on an indexed column. A list with 6,000 items
and an unfiltered default view is already broken.

## "What is in the recycle bin?"

```powershell
# Site level, both stages.
Get-PnPRecycleBinItem -FirstStage
Get-PnPRecycleBinItem -SecondStage

# Deleted site collections.
Get-PnPTenantRecycleBinItem
```

Check the tenant's actual retention window rather than assuming a default.

## "How much storage is being used?"

```powershell
Get-PnPTenantSite -Detailed |
  Select-Object Url, StorageUsageCurrent, StorageQuota |
  Sort-Object StorageUsageCurrent -Descending |
  Select-Object -First 20

Get-PnPTenant | Select-Object StorageQuota, StorageQuotaAllocated
```

Storage is pooled and the per-tier formula is not documented in this
repository yet. Report the numbers you read rather than computing an
entitlement.

## Reporting what you find

Distinguish what you observed from what you inferred. "The library has
unique permissions" is observed. "Somebody broke inheritance to give
Finance access" is inferred, and may be wrong.

Distinguish a finding from a violation. A finding is a fact. It is a
violation only if it contradicts `conventions.md`, and not even then if
the exceptions table in `profile.md` records it as a decision somebody
already made.

Write results to the cache directory with `Write-Oracle365Snapshot`, never
to this repository.
