# Licensing gates

Every recommendation Oracle365 makes passes through this file. Advice that
assumes a feature the tenant has not bought is worse than no advice,
because it sounds authoritative and wastes the reader's time proving it
wrong.

Check `license_tier` in `profile.md` before recommending anything below. If
it is unset, restrict advice to what every tier has, and say so.

## How to read this

Each claim carries a source and a verification date. A claim without both
is not usable. Microsoft moves features between tiers, renames SKUs, and
folds add-ons into base plans, so a year-old licensing claim is a guess.

"Minimum" means the cheapest plan that includes the feature outright. Most
features can also be bought as an add-on to a lower plan, which is how
small organizations usually end up with one capability above their tier.
Add-ons are not listed here. If the tier says no and the tenant swears they
have it, an add-on is the likely explanation. Check rather than argue.

## The gates

Verified 2026-09-21 against the sources named. Re-verify before relying on
any row older than twelve months.

| Feature | Minimum plan | Source |
|---|---|---|
| Sensitivity labels, basic | Business Premium or E3 | Purview service description |
| Auto-labeling | E5 or Purview add-on | Purview data lifecycle docs |
| Retention policies, org-wide or location-wide | Business Premium or E3 | Purview service description |
| Retention labels, applied manually | Business Premium or E3 | Purview service description |
| Auto-apply retention labels, default labels | E5 or Purview add-on | Purview data lifecycle docs |
| Data Loss Prevention, basic | Business Premium or E3 | Purview service description |
| Conditional Access | Entra ID P1, included in Business Premium | Entra licensing |
| Risk-based Conditional Access | Entra ID P2 | Entra licensing |
| Access reviews | Entra ID P2 | Entra ID Governance licensing |
| Power Platform premium connectors | Premium Power Apps or Power Automate license | Power Platform licensing |
| Dataverse for standalone apps and premium flows | Premium Power Platform license | Power Platform licensing |

Sources:

- Microsoft Purview service description, `learn.microsoft.com/office365/servicedescriptions`
- Microsoft Entra licensing, `learn.microsoft.com/entra/fundamentals/licensing`
- Microsoft Entra ID Governance licensing fundamentals
- Power Platform licensing, `learn.microsoft.com/power-platform/admin`

### Not verified

Do not state these as fact. Check before use.

- SharePoint pooled storage formula and per-tier quotas
- SharePoint Premium feature set and its licensing
- Nonprofit grant SKUs and how their entitlements differ from the paid
  equivalents
- eDiscovery tiers
- Information barriers

## Business Basic and Business Standard

The common case in small organizations, and the most constrained. Neither
includes any row in the gates table above.

No sensitivity labels. No retention policies. No DLP. No Conditional
Access. No access reviews. Power Platform is limited to standard
connectors, which does include SharePoint, so flows and apps over
SharePoint lists work. Premium connectors and standalone Dataverse do not.

This is not a small gap. Most published SharePoint governance advice
assumes at least E3, and following it produces a plan the organization
cannot execute.

The difference between Basic and Standard is the desktop Office apps, not
compliance features. Upgrading Basic to Standard buys nothing here.
Business Premium is the step that changes governance, and it is a large
per-seat increase across a whole tenant.

### What governance looks like without those features

It is all manual and it all works. Say this plainly rather than presenting
the tenant's actual options as a degraded version of something better.

**Structure carries the load.** With no labels and no DLP, the only
reliable control over who sees what is which site content sits in. A site
per access boundary matters more here than in a tenant that can label its
way out of a structural mistake.

**Site-level sharing settings.** Tenant sharing capability sets a ceiling
and each site can be tightened below it. This is available at every tier
and is the main external access control. Use it.

**Group membership, not direct grants.** With no access reviews, the only
sustainable model is group-based membership that somebody reviews on a
calendar. Direct user grants become invisible debt.

**Versioning and the recycle bin.** These replace retention for most
practical purposes at this tier: accidental deletion and overwriting are
what retention policies usually get bought for. Neither is a legal hold.
If the organization has a genuine records retention obligation, that is a
licensing conversation, not a configuration one.

**Named owners, at least two per site.** Costs nothing, and a departing
volunteer orphaning a site is the most common failure mode in a small
organization.

**A written review cadence.** With no automation to enforce policy, a date
in a calendar is the enforcement mechanism. Quarterly is realistic.
Annually is what actually happens.

### What to stop recommending at this tier

- Sensitivity labels for anything
- Retention policies, retention labels, and records management
- DLP rules
- Conditional Access for restricting access by device or location
- Automated access reviews
- Premium connectors in flows, including most non-Microsoft systems
- Dataverse as an alternative to SharePoint lists

## Determining the tier

`scripts/read/Get-TenantProfile.ps1` reads Graph `/subscribedSkus` and
reports subscribed SKUs with their provisioned service plans.

Service plan names are the better signal. A SKU name says what was bought.
A service plan says what is actually provisioned, which is what matters
when a tenant has mixed licensing, an add-on, or a legacy plan.

Reading this needs Graph `LicenseAssignment.Read.All` at minimum, which
app-only `Sites.Selected` does not provide. Run it delegated as an
administrator, or read the tier from the Microsoft 365 admin center under
Billing, then Your products, and record it by hand.

Mixed licensing is normal. Recording a single tier in `profile.md` is a
simplification, and where it matters, record which users have what.

## When this file is wrong

Assume it eventually will be. The failure mode to avoid is not being out of
date; it is being out of date silently.

If a claim here contradicts what the tenant actually does, the tenant is
right. Update the row, update the verification date, and note what changed.
