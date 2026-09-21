# Sharing and external access

At Business Basic and Business Standard this is the main external access
control available. There is no DLP, no sensitivity labels, and no
Conditional Access to fall back on, so the sharing settings carry weight
they would not carry in an E3 tenant.

Verified against Microsoft Learn, 2026-09-21.

## Three levels

**Tenant** sets the ceiling. No site can exceed it. Changing it affects
every site at once, which is rarely what anyone expects when they ask to
"tighten sharing."

**Site** can be tighter than the tenant, never looser.

**Item** is the individual sharing link or direct grant.

Change the narrowest level that solves the problem. A single library
sharing too widely is not a reason to change the tenant setting.

## Sharing capability values

Most to least permissive:

| Value | Meaning |
|---|---|
| `ExternalUserAndGuestSharing` | Anonymous links permitted |
| `ExternalUserSharingOnly` | Authenticated guests only |
| `ExistingExternalUserSharingOnly` | Only guests already in the directory |
| `Disabled` | Internal only |

Anonymous means exactly that. Anyone holding the URL reaches the content,
with no sign-in, and the audit trail records the link rather than a
person. A forwarded email is a permanent unlogged grant.

**A site tighter than the tenant was set deliberately. A site sitting at
the tenant ceiling may just be a default nobody touched.** Only the first
tells you somebody made a decision. When auditing, that distinction is
most of the signal.

## Link types

| Type | Who it works for |
|---|---|
| Anyone | Anybody with the URL, no sign-in |
| People in your organization | Any signed-in tenant member |
| People with existing access | Nobody new; generates a URL for people who already have access |
| Specific people | Named recipients only |

"People with existing access" grants nothing. It is a way to send a link
without changing permissions, and it is the right default for internal
sharing.

A link that works for one person and not another is usually the wrong link
type rather than a permissions problem. Check that before investigating
permissions.

## What tightening a policy does not do

Changing a sharing setting does not reliably revoke links already issued
under the old one. Treat existing links as outstanding until verified
individually, not as retroactively cancelled.

This is the single most common wrong assumption about SharePoint sharing.
Somebody disables anonymous links, believes the problem is solved, and the
links issued last month keep working.

Finding existing links means `Get-PnPFileSharingLink` and
`Get-PnPFolderSharingLink`, per item. There is no tenant-wide enumeration
that finishes in reasonable time.

## Guests

An external user who accepts an invitation becomes a guest in the
directory and holds standing access until somebody removes them.

At Business Basic there are no access reviews, which need Entra ID P2. The
only mechanism that removes a stale guest is a person deciding to look.
That means a calendar entry, because nothing else will prompt it.

Worth checking for each guest: are they still involved, is the project
over, did they leave the partner organization.

`Get-PnPExternalUser` lists them, tenant-wide or per site. It pages, and
the default returns a first page rather than everything.

## Settings worth knowing

**Default link type** is what the Share dialog offers first. Most people
accept the default. Setting it to "People with existing access" or
"Specific people" changes behavior across the organization more reliably
than any amount of training.

**Default link permission** is view or edit. View is the safer default.

**Anonymous link expiry** puts a maximum lifetime on anonymous links. If
anonymous sharing is enabled at all, this should be set.

**Domain restriction** allows or blocks sharing by recipient domain. For
an organization that works with a known set of partners, an allow list is
a genuinely strong control and costs nothing.

## A realistic stance for a small organization

Not a recommendation for any particular tenant. A starting point to argue
with, recorded in `conventions.md` once decided.

- Tenant at `ExternalUserSharingOnly`, so external sharing works but
  requires sign-in and produces an auditable identity
- Anonymous enabled only on specific sites with a reason recorded
- Default link type "People with existing access"
- Default link permission view
- Domain allow list if the partner set is known and stable
- Guest review on the calendar, twice a year, with somebody's name on it

The reason to prefer authenticated guests over anonymous links is not
security theatre. It is that a guest has a name in the audit log and can
be removed, and an anonymous link has neither property.
