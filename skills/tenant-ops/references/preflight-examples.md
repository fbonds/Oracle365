# Preflight examples

Worked preflights for operations that actually come up. Use them as a
shape, not a script: every field must be filled from the live tenant, not
copied from here.

Verified against PnP PowerShell documentation, dev branch, 2026-09-21.

## The rules these examples follow

Read current state live, immediately before showing the preflight. Never
from a snapshot, never from memory, never from what somebody said.

Do not run the command in the same turn as the preflight. Show it, stop,
wait.

If you cannot determine a rollback, write that in the Rollback field.
Never leave it blank and never guess.

## Tighten sharing on one site

```
PREFLIGHT
Target:        https://contoso.sharepoint.com/sites/finance
Current state: SharingCapability = ExternalUserAndGuestSharing
               (anonymous links permitted)
Proposed:      SharingCapability = ExternalUserSharingOnly
               (authenticated guests only)
Blast radius:  3 external users currently hold access and keep it.
               2 anonymous links exist against this site. Changing the
               policy does not reliably revoke links already issued.
               Verify each one separately.
               No flows or apps reference this site.
Rollback:      Set-PnPTenantSite -Identity https://contoso.sharepoint.com/sites/finance `
                 -SharingCapability ExternalUserAndGuestSharing
```

The blast radius line is the work. Anyone can read a setting. Knowing that
existing links survive the change is what stops this being a surprise next
week.

## Add a second site collection administrator

```
PREFLIGHT
Target:        https://contoso.sharepoint.com/sites/membership
Current state: 1 site collection administrator: alice@contoso.org
Proposed:      Add bob@contoso.org as site collection administrator
Blast radius:  Bob gains full control of this site including all
               libraries, and can grant access to others. He does not
               gain access to any other site.
Rollback:      Remove-PnPSiteCollectionAdmin -Owners bob@contoso.org
```

This is the fix for the most common governance finding in a small
organization. A site with one administrator is one resignation from being
orphaned.

## Restore inheritance on a library

```
PREFLIGHT
Target:        Documents library, https://contoso.sharepoint.com/sites/finance
Current state: HasUniqueRoleAssignments = True
               Direct grants: carol@contoso.org (Contribute),
               "Finance Reviewers" group (Read)
Proposed:      Reset to inherit from the site
Blast radius:  Carol and Finance Reviewers lose their library-specific
               grants. They keep whatever the site gives them, which for
               Carol is Read via "Finance Members" and for Finance
               Reviewers is nothing. Finance Reviewers lose access
               entirely.
Rollback:      Re-break inheritance and re-add both grants:
                 Set-PnPListPermission -Identity Documents -User carol@contoso.org -AddRole Contribute
                 Set-PnPListPermission -Identity Documents -Group "Finance Reviewers" -AddRole Read
               Rollback restores the grants but not the original
               inheritance-break metadata. Functionally equivalent, not
               byte-identical.
```

Note what the blast radius did: it worked out what each principal keeps,
not just what they lose. "Finance Reviewers lose access entirely" is the
sentence that makes someone say wait.

Note also the honest rollback caveat. Saying a rollback is approximate is
better than implying it is exact.

## Bulk: tighten sharing across many sites

Over 10 objects, so a dry run comes first, not a preflight.

```
DRY RUN
Operation:     Set SharingCapability = ExternalUserSharingOnly
Scope:         14 sites currently at ExternalUserAndGuestSharing
Read live:     2026-09-21T14:02:11Z

  /sites/finance          ExternalUserAndGuestSharing -> ExternalUserSharingOnly
  /sites/membership       ExternalUserAndGuestSharing -> ExternalUserSharingOnly
  ... all 14 listed, none sampled ...

Aggregate blast radius:
  9 external users across these sites keep their access
  23 anonymous links exist and may survive the change
  1 site (/sites/publicevents) appears to use anonymous links
    deliberately for a public calendar. Worth excluding.

Rollback:      Per site, restore the recorded prior value. Full list of
               prior values is in the snapshot at <path>.
```

Enumerate all 14. Do not sample. The one site that should be excluded is
exactly the one sampling would miss.

Execute in batches, verifying between them. Stop at the first unexpected
result rather than completing the run and reporting a list of failures.

## Irreversible: delete a site

```
PREFLIGHT
Target:        https://contoso.sharepoint.com/sites/oldproject
Current state: 2.1 GB across 4 libraries, 1,840 items.
               Last content modification 2024-03-11.
               Owner: dmitri@contoso.org, account disabled.
Proposed:      Delete the site collection
Blast radius:  All content becomes inaccessible immediately.
               No other site references it.
               The backing Microsoft 365 group is also deleted.
Rollback:      Without -SkipRecycleBin the site goes to the tenant recycle
               bin and can be restored with
                 Restore-PnPTenantRecycleBinItem -Identity <url>
               Confirm the tenant's actual retention window before
               relying on it rather than assuming a default.
               With -SkipRecycleBin there is NO ROLLBACK.

THIS CANNOT BE UNDONE ONCE THE RECYCLE BIN RETENTION EXPIRES.
Confirm in a separate message. This will not be bundled with other changes.
```

Two things this example is doing deliberately.

It distinguishes `Remove-PnPTenantSite` from
`Remove-PnPTenantSite -SkipRecycleBin`. The first is recoverable for a
window. The second is not recoverable at all. Treating them as the same
operation is how content gets lost.

It refuses to state a retention period from memory. Check the tenant.

## When there is no rollback

Say so in the field. Do not leave it blank, do not write "none", and do
not invent something plausible.

```
Rollback:      NONE. Emptying the second-stage recycle bin is permanent.
               Deleted items cannot be recovered by any administrator,
               including Microsoft support.
```

Then require confirmation in a separate message, and do not bundle it with
anything else.

## After approval

1. Re-read current state. If it changed since the preflight, stop and
   re-run the preflight.
2. Execute.
3. Read the new state back. Do not report success from the absence of an
   error.
4. Append to `changelog.md` in the cache directory with
   `Write-Oracle365ChangeLog`.

Step 3 catches the case where a command succeeds and does nothing, which
is more common in SharePoint than it should be.
