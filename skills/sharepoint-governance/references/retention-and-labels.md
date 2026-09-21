# Retention and labels

Read `knowledge/_shared/licensing.md` before recommending anything here.
Most of this is licence-gated, and at Business Basic or Business Standard
none of it exists.

Verified against Microsoft Learn, 2026-09-21.

## What needs what

| Feature | Minimum plan |
|---|---|
| Sensitivity labels, basic | Business Premium or E3 |
| Auto-labeling | E5 or Purview add-on |
| Retention policies, org-wide or location-wide | Business Premium or E3 |
| Retention labels, applied manually | Business Premium or E3 |
| Auto-apply retention labels, default labels | E5 or Purview add-on |

`licensing.md` holds the maintained version with sources. If this table
and that one disagree, that one is right.

## If you do not have them

Which is the common case in a small organization. Say so directly rather
than describing what could be bought.

**Versioning** is the practical substitute for retention against the
failure retention is usually bought for: somebody overwrote or deleted the
wrong thing. It is on by default for libraries and available at every
tier. Check the version limit per library and raise it where content
matters.

**The recycle bin** has two stages, then it is gone. Know the tenant's
actual retention window before you need it rather than assuming a
published default.

**Structure** substitutes for sensitivity labels. With no labels, the only
reliable control over who sees what is which site the content sits in. A
site per access boundary matters more here than in a tenant that can label
its way out of a structural mistake.

**A written policy** substitutes for an enforced one. "Financial records
are kept for seven years in the Finance site and not deleted" is a real
control if somebody owns it, even with nothing enforcing it technically.
Record it in `conventions.md`.

## Where the substitutes fall down

Be honest about this rather than presenting the workaround as equivalent.

Versioning and the recycle bin are not a legal hold. They do not prevent
deletion, they do not survive a determined user, and they do not produce
the defensible audit trail a records obligation requires.

An organization with a genuine statutory or regulatory retention
obligation, which includes many nonprofits for financial and membership
records, has a licensing question rather than a configuration question.
Say that plainly. It is a board conversation, not a SharePoint setting.

The honest framing: at Business Basic you can be organized and careful.
You cannot be compliant in the sense a regulator would mean.

## If you do have them

**Retention policies** apply to a location: a site, all sites, a group.
They work in the background and users do not see them.

**Retention labels** apply to an item and are visible. Manual application
means somebody has to do it, which means mostly nobody does. That is why
auto-apply exists, and why auto-apply sits behind E5.

Retention and deletion are the same feature. A retention policy that
deletes after seven years is doing both, and the deletion half is the part
that surprises people.

**Sensitivity labels** control encryption, access, and sharing, and they
override permissions. A file can be labeled so that someone with Full
Control on the library still cannot open it.

That last point matters for troubleshooting: a sensitivity label produces
an access denial that looks exactly like a permissions bug, and no amount
of permission investigation will explain it. When access is denied and
permissions look correct, check for a label.

## Order of operations

Do not start with labels or retention even where they are available.

1. Get the structure right, since labels applied over a bad structure make
   it harder to fix, not easier
2. Get permissions and groups right
3. Get sharing settings right
4. Only then consider labels and retention

Every step above is available at every tier. The gated features are the
last thing to reach for, not the first.
