---
name: sharepoint-triage
description: Diagnose a SharePoint Online problem that is happening now. Use when somebody cannot access something, search is not returning results, OneDrive sync is failing, a sharing link does not work, a flow or app has broken, files are missing, or a migration went wrong. Triggers on cannot access, access denied, permission denied, not working, broken, missing, search not finding, not indexed, sync error, sync stuck, link expired, flow failed, error message, suddenly stopped, used to work.
---

# SharePoint triage

Something is broken now. Diagnose before proposing. The most common
mistake is redesigning the permissions model when one user needs adding to
one group.

## Method

1. **Establish what changed.** "It used to work" narrows the search
   enormously. Ask when it last worked.
2. **Reproduce or observe.** Read the actual state through `tenant-ops`.
   Do not diagnose from a description when you can look.
3. **Narrow the blast radius.** One user or everyone? One file or the
   library? One device or all devices?
4. **Fix narrowly.** The smallest change that resolves it.
5. **Record it.** If the cause was a deliberate exception, it belongs in
   the exceptions table in `profile.md` so the next audit does not flag it.

## Access problems

Check in this order. Stop when you find it.

1. Is the user in the group they should be in? Check actual membership,
   not intended membership.
2. Has inheritance been broken anywhere on the path? Site, library,
   folder, item.
3. Is it a sharing link rather than a permission? Links expire.
4. Is the user a guest, and is guest access still enabled at the tenant
   and site level?
5. Is a sensitivity label restricting it? Labels override permissions and
   produce access denials that look like permission bugs.
6. Is Conditional Access blocking the device or location?
7. Has the account been disabled or the license removed?

Group membership changes can take time to propagate. If membership looks
correct and access is denied, check how recently it changed before
concluding the membership is wrong.

## Search

Search problems are usually indexing, and indexing is not instant.

Check: is the content in a library excluded from search, is the site
excluded, has the item been modified since the last crawl, is there a
search schema issue with a custom column, does the user have permission
(search is permission-trimmed, so "not found" and "not allowed" look
identical to the user).

A managed property that is not searchable or queryable will silently
return nothing.

## Sync

Known OneDrive sync limits: path length, invalid characters, file size,
files in use, and libraries with more items than the client handles well.

Check whether the library uses features the sync client does not support.
Check whether files are in a checked-out state.

"Sync is stuck" is frequently one file blocking the queue. Find the file.

## Sharing links

Link types behave differently: Anyone, People in your organization,
People with existing access, Specific people. A link that works for one
person and not another is usually the wrong link type rather than a
permissions problem.

Check expiration, check whether the link's permission level matches what
the user is trying to do, and check whether policy changed after the link
was issued.

## Flows and apps

Check the run history first; it usually names the failure.

Common causes: the connection owner left or their password changed, a
column was renamed or its type changed, a delegation limit is now being
hit as the list grew, throttling, or a license lapsed on a premium
connector.

A flow that "worked yesterday" and now fails on a larger list is a
delegation or threshold problem, not a flow bug.

## Migration

Check for: path length, unsupported characters, files exceeding size
limits, metadata not mapped, permissions not carried across, versions
dropped, and content types not existing at the destination.

Verify counts at both ends before declaring a migration complete.

## Executing

Route every read and write through `tenant-ops`.

## Reference

- `references/access-diagnostics.md`
- `references/search-and-indexing.md`
- `references/sync-issues.md`
- `references/sharing-links.md`
- `references/flow-and-app-failures.md`
- `references/migration-issues.md`
