# Audit checklist

What to run, in what order, and what to do with the output.

An audit produces findings. A finding is a fact. It becomes a violation
only when it contradicts `conventions.md`, and not even then if the
exceptions table in `profile.md` records it as a decision somebody already
made. Keep those three things separate when reporting, or the report gets
ignored.

## Before starting

Read `conventions.md`. Without it there is no standard to measure against
and every finding is just an observation. If it is empty, say so: the
output is then a description of the tenant, not an audit.

Read the exceptions table in `profile.md`. Re-reporting a known exception
every quarter is how people learn to ignore audit output.

Check `license_tier`. It determines which findings are actionable. At
Business Basic there is no point reporting the absence of sensitivity
labels.

## Order

```powershell
# 1. What exists. Everything else uses this.
./scripts/read/Get-SiteInventory.ps1 -AdminUrl https://<tenant>-admin.sharepoint.com

# 2. Licensing and tenant settings.
./scripts/read/Get-TenantProfile.ps1 -AdminUrl https://<tenant>-admin.sharepoint.com

# 3. External exposure.
./scripts/read/Get-SharingReport.ps1 -AdminUrl https://<tenant>-admin.sharepoint.com -FromInventory

# 4. Permissions. Slowest. Run last.
./scripts/read/Get-PermissionsAudit.ps1 -FromInventory
```

All four default to `-Mode Delegated`. Tenant-wide reads cannot run
app-only under `Sites.Selected`.

Run the inventory first. The other two reuse its snapshot rather than
re-enumerating, which is faster and avoids a second round of throttling.

## Findings worth acting on

Ordered by how much damage they cause, not by how easy they are to fix.

**Sites with one or no owner.** The highest-value finding in a volunteer
organization. Turnover is high and offboarding is informal. Fix by adding
a second owner, which is a small, safe, reversible change.

**Orphaned sites.** No owner, or the owner's account is gone. Assign an
owner before deciding anything else about the site.

**Anonymous sharing where it was not intended.** Anyone with the URL, no
sign-in, no identity in the audit log. Check each site individually: some
will be deliberate.

**Guests who are no longer involved.** Standing access with nothing to
prompt removal. At Business Basic there are no access reviews, so this
list only shrinks when somebody reads it.

**Broken inheritance with no recorded reason.** Each instance is a
standing maintenance cost and a place where site-level changes silently
fail to apply. Investigate before removing: the reason may still be valid
and simply undocumented.

**Direct user grants where a group would do.** Invisible debt. Does not
appear in group membership, does not get removed on role change.

**Everyone, or Everyone except external users.** Not automatically wrong.
Should always be deliberate.

**Empty SharePoint groups.** Usually harmless, occasionally the remains of
a permission model somebody abandoned halfway.

## What to do with the output

Do not send a list of 80 findings to a volunteer board. It will not be
read and it will make the next report easier to ignore.

Pick the three that matter, say what each costs if left alone, and propose
one concrete fix each. Keep the full snapshot for anyone who wants it.

Fix the safe, reversible things first: adding second owners, removing
guests who are plainly gone. Building a track record of small correct
changes buys the credibility needed for the larger ones.

## Recording decisions

When a finding turns out to be deliberate, record it in the exceptions
table in `profile.md` with the reason, who decided, and when. That is the
only way the next audit does not rediscover it.

When a finding produces a new rule, record it in `conventions.md`. A rule
without a reason gets broken the first time it is inconvenient, so write
the reason.

## Cadence

Quarterly is realistic to propose. Annually is what happens. Plan for
annually.

Attach it to something that already occurs: a board meeting, an officer
handover, the start of a programme year. An audit with no calendar anchor
happens once.

Officer handover is the highest-value moment in a club, because the
permissions questions are already live and somebody is already thinking
about who has access to what.
