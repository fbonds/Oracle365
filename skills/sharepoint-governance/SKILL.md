---
name: sharepoint-governance
description: Design and maintain SharePoint Online governance. Use for permissions models, sharing and external access policy, site lifecycle and provisioning standards, sensitivity labels, retention, sprawl cleanup, access reviews, and orphaned or abandoned sites. Triggers on permissions, who can see, sharing, external, guest, retention, label, policy, lifecycle, provisioning, naming standard, sprawl, cleanup, audit, offboarding, ownership.
---

# SharePoint governance

Governance is deciding the rules and keeping reality matching them. A
permissions problem that is broken right now is triage, not governance.

## Order of operations

1. Read `conventions.md` from the config directory. If a rule already
   exists, apply it rather than proposing a new one. If it is empty, say
   so: the answer is then a proposal, not a standard.
2. Check `license_tier` in `profile.md` before recommending anything in
   the gated list below.
3. Check the exceptions table in `profile.md`. A deviation recorded there
   is a decision, not a finding.

## License gates

Do not recommend these without confirming the tier:

| Feature | Typically requires |
|---|---|
| Sensitivity labels | Entra ID P1 or above, Purview |
| Auto-labeling | E5 or Information Protection add-on |
| Purview retention policies | E3 or above |
| Data Loss Prevention | E3 for basic, E5 for full |
| Conditional Access | Entra ID P1 |
| Access reviews | Entra ID P2 |
| Insider risk | E5 |

Tiers change. Verify against current Microsoft licensing rather than
trusting this table alone. It is a prompt to check, not an authority.

At Business Basic or Standard, most of the above is unavailable.
Governance there is site-level settings, group hygiene, naming discipline,
and manual review. Say that plainly rather than recommending what cannot
be bought.

## Permissions

Default position: inherit. Unique permissions are a cost paid forever, by
whoever inherits the tenant.

Before proposing unique permissions, establish that group membership
cannot solve it. Most requests for unique permissions are really requests
for a group that does not exist yet.

When auditing, report:

- Where inheritance is broken, and whether anything documents why
- Direct user grants that should be group grants
- Sharing links that grant more than the site's stated stance
- Everyone and Everyone except external users, anywhere
- Sites with fewer than two owners
- Guests with access, and whether they are still active

Distinguish a finding from a violation. A finding is a fact. A violation
is a finding that contradicts `conventions.md`.

## Sharing and external access

Tenant setting is a ceiling. Site setting cannot exceed it. Say which of
the two you are recommending changing, because tightening the tenant
setting silently affects every site.

Existing links survive policy changes in ways people do not expect.
Disabling anonymous links does not retroactively kill issued links in
every case. Check rather than assert.

## Lifecycle

Provisioning without a matching deprovisioning plan produces sprawl on a
predictable schedule.

Every site needs an owner who is a person, at least two of them, and a
review date. Sites whose owner has left are the most common governance
failure in small organizations.

For cleanup, classify before acting: active, dormant but needed, dormant
and unneeded, orphaned. Only the last two are candidates, and orphaned
sites need an owner assigned before anything else is decided.

## Executing

This skill does not touch the tenant. Route every read and write through
`tenant-ops`.

## Reference

- `references/permissions-model.md`
- `references/sharing-and-external.md`
- `references/site-lifecycle.md`
- `references/retention-and-labels.md`
- `references/audit-checklist.md`
