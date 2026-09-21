---
name: sharepoint-architecture
description: Design SharePoint Online structure. Use for deciding site versus hub versus subsite, information architecture, navigation, content types and metadata, list versus library versus Dataverse versus a real database, tenant topology, and where a given kind of content should live. Triggers on architecture, structure, design, where should, hub, site collection, taxonomy, metadata, content type, navigation, information architecture, organize.
---

# SharePoint architecture

Structural decisions are the expensive ones. Migrating content later costs
more than getting the shape right, and permissions inherit from structure,
so a bad shape becomes a permissions problem within a year.

## Order of operations

1. Read `conventions.md`. Existing structural rules bind.
2. Read the site topology in `profile.md`. Do not design in the abstract
   when the actual topology is on disk.
3. Ask what the content is and who needs it before proposing a shape.
   Structure follows access boundaries.

## The main decisions

**Flat sites with hubs, not subsites.** Subsites are legacy. They inherit
permissions in ways that become hard to unpick, and they cannot be moved.
A new subsite in 2026 needs a specific justification.

**A site per access boundary.** If two bodies of content have different
audiences, they are two sites. If they have the same audience, they are
probably one site with two libraries.

**Hubs for association, not hierarchy.** A hub gives shared navigation,
search scope, and theme. It does not give shared permissions. People
expect it to, and are surprised.

**Team site or communication site.** Team site for a group working
together, group-backed, membership-driven. Communication site for
publishing to a wide audience, a few authors, many readers.

## List, library, or something else

| Need | Use |
|---|---|
| Documents with versions and co-authoring | Document library |
| Structured records, tens of thousands of rows | SharePoint list |
| Structured records, hundreds of thousands | Dataverse or a database |
| Relational data with referential integrity | Dataverse or a database |
| Anything needing transactions | Not SharePoint |

The list view threshold is 5,000 items per view, not per list. A list can
hold millions; a view that returns more than 5,000 fails. Indexing and
filtered views solve most of it. Say this precisely, because it is the
most commonly garbled fact in SharePoint.

Dataverse carries licensing cost. Check `license_tier` before proposing
it.

## Metadata

Managed metadata is powerful and consistently over-applied in small
organizations. It needs somebody to curate the term store. If nobody owns
it, choice columns are the honest answer.

Site columns and content types at the tenant level need a hub or the
content type gallery. Check what exists before creating another.

## Executing

Route every read and write through `tenant-ops`.

## Reference

- `references/site-and-hub-design.md`
- `references/information-architecture.md`
- `references/list-vs-library-vs-dataverse.md`
- `references/content-types-and-metadata.md`
