# Site lifecycle

Provisioning without a matching deprovisioning plan produces sprawl on a
predictable schedule. Every site anyone creates is permanent unless
somebody decides otherwise, and nobody ever decides otherwise unless a
process makes them.

## Creation

Decide who may create sites. The tenant setting is `SiteCreationMode`.

Open self-service creation in a volunteer organization produces a site per
event, per committee, per year, most of them abandoned within months. The
cost is not storage. It is that nobody can find anything, and that each
abandoned site carries permissions nobody reviews.

Closed creation produces a bottleneck and people route around it, usually
into personal OneDrive, which is worse.

The middle position that works: anyone may request, a named person
approves, and approval takes a day rather than a month.

## Required at creation

Cheap to demand at creation, expensive to retrofit.

- **A purpose**, one sentence, recorded on the site itself
- **Two owners**, both people, not one person and a shared account
- **A review date**, which is the only thing that will ever cause
  somebody to revisit this
- **A naming decision** consistent with `conventions.md`

The two-owner rule is the highest-value item on this list for a volunteer
organization. Turnover is high and offboarding is informal: somebody
simply stops coming. A site with one owner becomes orphaned without anyone
noticing, and recovering it needs a tenant administrator.

## Naming

Record the convention in `conventions.md` and apply it at creation. A site
URL cannot be changed after creation without moving content.

What the convention is matters less than having one and holding to it.
Prefixes that group related sites help more than clever abbreviations.

Avoid dates in site names unless the site is genuinely for one year only.
"Gala 2026" invites "Gala 2027" and so on, and within five years nobody
knows which ones still matter.

## Review

Without automation, a review is a calendar entry with somebody's name on
it. Quarterly is realistic to propose. Annually is what actually happens.
Plan for annually and be pleased by anything better.

What a review asks, per site:

- Is this still in use? Check last content modification, not the feeling.
- Are both owners still involved?
- Does the permission set still match who should have access?
- Are there guests who should no longer be here?
- Has anything been shared anonymously?

`scripts/read/Get-SiteInventory.ps1` answers the first two mechanically.

## Classifying a dormant site

Dormant is a prompt to look, not a verdict. Before acting, classify:

**Active.** Recent modification. Nothing to do.

**Dormant but needed.** Reference material, archived minutes, records
somebody will want in three years. Leave it, and consider making it
read-only so it stops accumulating.

**Dormant and unneeded.** A candidate. Content can go, but confirm with
somebody who was involved before assuming.

**Orphaned.** No owner, or the owner has left. This is not a deletion
candidate. It is a site needing an owner assigned before anybody can
decide anything about it.

The failure mode is treating dormant as unneeded. In a club, the
membership records from four years ago are dormant and are exactly what
somebody will need.

## Archiving

At Business Basic, archiving means setting a site read-only and leaving
it, rather than any product feature. That is a legitimate answer. It keeps
the content findable, stops it drifting, and costs nothing.

Record what was archived and when, because otherwise the next review
rediscovers it as dormant.

## Deletion

`Remove-PnPTenantSite` sends the site to the tenant recycle bin, where
`Restore-PnPTenantRecycleBinItem` can bring it back for a retention
window. Check the tenant's actual window rather than assuming a default.

`Remove-PnPTenantSite -SkipRecycleBin` is permanent immediately.

Deleting a group-connected team site also deletes the backing Microsoft
365 group, which takes its mailbox, calendar, and Teams presence with it.
People are routinely surprised by this.

Before deleting anything: export what matters, tell the people who used
it, and wait. There is no hurry. A dormant site costs almost nothing to
leave in place for another month.

## Offboarding

The lifecycle event that actually happens most often in a volunteer
organization, and the one with no product support at this tier.

When somebody leaves:

- Find the sites where they are an owner or the only administrator
- Assign replacements before disabling the account, not after
- Check for direct user grants, which are invisible in group membership
- Check whether any Power Automate flows run under their connection, since
  those break when the account goes
- Their OneDrive has a retention window after account deletion; know what
  it is before you need it

Doing this after the account is gone is considerably harder than doing it
before.
