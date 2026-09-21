---
name: tenant-ops
description: Read from or write to a live SharePoint Online tenant. Use for inspecting sites, permissions, settings and storage; auditing; generating inventory; and for every operation that changes tenant state. This is the only skill permitted to execute against the tenant. Triggers on inspect, audit, check, list, report, provision, create site, set permissions, change sharing, apply policy, run, execute.
---

# Tenant operations

Every operation that touches the live tenant goes through this skill. Other
skills draft commands. This skill runs them.

## Before anything

1. Resolve the config directory per `AGENTS.md`. If `profile.md` does not
   exist, stop and offer first-run setup. Do not proceed on assumptions.
2. Read `profile.md`. Note the permission model, the granted sites, the
   license tier, and the administrative roles held.
3. Confirm the operation is within the granted scope. Under
   `Sites.Selected`, an operation against an ungranted site will fail.
   Say so before running it, not after.

## Connecting

App-only, certificate-based. A client secret is not supported for
SharePoint CSOM and REST.

```powershell
Connect-PnPOnline -Url <site-url> `
  -ClientId <client_id> `
  -Tenant <tenant>.onmicrosoft.com `
  -Thumbprint <certificate_thumbprint>
```

Read the values from `profile.md`. Never prompt the user to paste a
thumbprint into the conversation when it is already on disk.

Interactive auth (`-Interactive`) is acceptable for a one-off read where
no app registration exists yet. It is not acceptable for anything
scheduled or repeated.

## Reads

Run freely. No approval needed.

Prefer reading over asking. If the user asks why someone cannot see a
library, go look at the library rather than asking them to describe its
permissions.

Write results to the cache directory, not the repository. Stamp every
inventory file with the time it was generated and the scope it covers.

When reporting, distinguish what you observed from what you inferred.

## Writes

Never in the same turn as the preflight. Present the preflight, stop, wait.

```
PREFLIGHT
Target:        <resource, fully qualified>
Current state: <read live, immediately before showing this>
Proposed:      <what it becomes>
Blast radius:  <who and what else is affected>
Rollback:      <exact reversing command, or an explicit statement that
                there is none>
```

### Determining blast radius

Answer these before writing the field. If you cannot answer one, say so in
the preflight rather than omitting it.

- Who currently has access that this changes?
- Does anything inherit from this object?
- Are there active sharing links pointing at it?
- Does a flow, app, or integration depend on it?
- Is it referenced by a retention policy or label?

Inheritance is the one most often missed. Changing a site's permissions
changes every library that inherits, which is usually all of them.

### After approval

1. Re-read the current state. If it changed since the preflight, stop and
   re-run the preflight.
2. Execute.
3. Verify by reading back the new state. Do not report success from the
   absence of an error.
4. Append to `changelog.md` in the cache directory.

## Bulk operations

More than 10 objects requires a dry run first: every affected object
listed, the change per object, the aggregate blast radius. User approves
the dry run, then you execute.

Do not sample. If the operation affects 200 objects, enumerate 200.

Execute in batches and verify between them. Stop at the first unexpected
result rather than completing the run and reporting a list of failures.

## Irreversible operations

These cannot be rolled back, or can only be rolled back on a timescale
that makes it theoretical:

- Deleting a site collection
- Emptying the second-stage recycle bin
- Removing the last site collection administrator
- Deleting a content type or site column in use
- Disabling external sharing where active links exist
- Deleting a Microsoft 365 group backing a team site

For these: state plainly that it cannot be undone, require confirmation in
a separate message, and never bundle one with other changes.

For site deletion specifically, check the retention period for the
tenant's recycle bin and state the actual window rather than assuming 93
days.

## Refusals

Decline and explain, rather than complying, when:

- The operation would exceed the granted permission scope and the fix
  proposed is to widen the grant tenant-wide
- A conventions file marks the change as a non-negotiable violation, and
  the user has not explicitly overridden it
- The operation would write tenant data into this repository
- The rollback is unknown and the operation is irreversible, and the user
  has not acknowledged both facts

Declining is not refusing to help. Say what you will do instead.

## Reference

- `references/preflight-examples.md`
- `references/connection-patterns.md`
- `references/read-recipes.md`
