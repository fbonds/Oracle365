# Permissions model

Verified against Microsoft Learn, 2026-09-21. Sources named per section.

## Default permission levels

| Level | Grants | Editable |
|---|---|---|
| Full Control | Everything | No |
| Design | View, add, update, delete, approve, customize layout | Yes |
| Edit | Contribute plus add, edit and delete lists | Yes |
| Contribute | Add and change items in lists and libraries | Yes |
| Read | View only | Yes |
| View Only | View, without downloading | Yes |
| Limited Access | Reach one item without site access | No |

Full Control and Limited Access cannot be edited. The rest can, and
editing a default level is a decision to regret later: it changes behavior
everywhere it is used, invisibly. Copy it and edit the copy.

**Limited Access is not something you assign.** SharePoint grants it
automatically when somebody is given access to an item inside a container
they cannot otherwise see. Finding it in an audit means somebody was given
item-level access, not that a person configured Limited Access.

Source: Understanding permission levels in SharePoint, `learn.microsoft.com/sharepoint/understanding-permission-levels`

## Default groups

Every site has Owners, Members, and Visitors.

| Group | Default level |
|---|---|
| Site Owners | Full Control |
| Site Members | Edit |
| Site Visitors | Read |

Classic sites and SharePoint Server gave Members **Contribute** rather
than Edit. If you are reading older documentation, or a site migrated from
an older tenant, check the actual level rather than assuming.

Edit versus Contribute matters: Edit lets somebody create and delete
lists and libraries, not just items in them. For most club scenarios
Contribute is the honest level and Edit is more than anyone needs.

## Group-connected team sites

A team site backed by a Microsoft 365 group behaves differently, and this
catches people out.

Group owners become site owners. Group members become site members. This
is automatic and you manage it through the group, not through SharePoint.

**You cannot modify permissions for the default groups on a
group-connected team site.** Owners, Members, and Visitors are fixed.

**Microsoft 365 groups have no view-only concept.** There is no way to be
a group member with read access. Anyone who should have read-only access
must be added directly to the site Visitors group, outside the group
entirely.

That last point is the one worth remembering. Read-only access on a
group-connected site is always a direct SharePoint grant, which means it
is invisible to anyone looking at group membership, and it survives being
removed from the group.

Source: Customize SharePoint site permissions, and Site permissions after
Microsoft 365 group connection, `learn.microsoft.com/sharepoint`

## Inheritance

Everything inherits from the site by default: libraries, lists, folders,
items.

Breaking inheritance is cheap to do and permanent to maintain. The copy
made at the moment of breaking does not track later changes to the parent,
so a site-level change silently fails to reach anything with unique
permissions. That gap is where most "why can this person still see it"
questions come from.

**Before breaking inheritance, establish that group membership cannot
solve it.** Most requests for unique permissions are really requests for a
group that does not exist yet. Creating "Finance Reviewers" and granting
it at site level costs nothing to maintain. Breaking inheritance on four
libraries costs forever.

Legitimate reasons to break inheritance:

- A genuinely more sensitive subset inside an otherwise open site, where
  moving it to its own site is worse for the people using it
- A library that must be read-only while the rest of the site is editable

Illegitimate reasons, which is most of them:

- One person needs access and nobody wants to create a group
- It was faster at the time
- Somebody was copying what another site did

Record every deliberate break in the exceptions table in `profile.md`.
Without that, every audit rediscovers the same findings and somebody has
to work out the history again.

## Groups, not direct grants

Grant to groups. Always.

A direct user grant is invisible debt. It does not show up when you look
at group membership, it does not get removed when somebody changes role,
and at Business Basic there are no access reviews to catch it. The only
mechanism that finds it is somebody running an audit and reading the
output.

This matters more in a volunteer organization than in a company, because
turnover is higher and offboarding is informal. Somebody stops coming to
meetings; nobody files a ticket.

## Special principals

**Everyone** includes external users. Almost never what anyone means.

**Everyone except external users** is the one people usually want, and is
still a bigger grant than most situations need. On a site of 156 people it
means all 156.

Finding either in an audit is worth a look in every case. Neither is
automatically wrong, but both should be deliberate.

## Site collection administrators

Full control of everything in the site collection, including things the
Owners group cannot reach. Not visible in the normal site permissions
interface, which is why it gets forgotten.

**Two minimum, always.** A site with one administrator is one resignation
away from being orphaned, and recovering an orphaned site needs a tenant
administrator. In a club, the single administrator is usually the person
who set the site up and has since moved on.

A guest holding site collection administrator is worth investigating in
every case.

## Auditing this

`scripts/read/Get-PermissionsAudit.ps1` reports admins, group membership,
and broken inheritance across sites. `references/audit-checklist.md` in
this folder covers what to do with the output.
