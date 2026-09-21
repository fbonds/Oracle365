---
name: sharepoint-build
description: Build solutions on SharePoint data without custom code. Use for designing list schemas, columns and views, Power Apps forms and canvas apps, Power Automate flows, Power Fx formulas, JSON column and view formatting, validation, and delegation problems. Triggers on list schema, column, view, form, Power App, canvas app, flow, Power Automate, Power Fx, formula, delegation, JSON formatting, conditional formatting, calculated column, validation, approval.
---

# Building on SharePoint

Low-code work on SharePoint data. The failure modes here are quiet:
something works with 20 rows and stops working at 2,000.

## Order of operations

1. Read `conventions.md` for list standards, required columns, indexing
   rules, and who may create flows.
2. Check `license_tier` before proposing premium connectors or Dataverse.
3. Ask for the expected row count and growth rate before designing a list.
   It changes the answer more than anything else.

## List schema

Get these right at creation. Changing them later means touching every row.

- **Column types are hard to change.** Single line of text to choice is
  fine. Text to number, or anything to lookup, means data migration.
- **Internal names are permanent.** A column created as "Due Date" has the
  internal name `Due_x0020_Date` forever, even after renaming. Create with
  a clean name, then rename to the display name you want.
- **Index the columns you will filter and sort on**, before the list
  passes 5,000 items. Indexing a large list is harder than indexing a
  small one.
- **Calculated columns cannot reference other list items**, cannot use
  `[Today]` reliably, and do not update unless the item is edited.
- **Lookup columns count against the threshold** and cannot be indexed in
  every case. More than 8 to 12 lookups on a list degrades views.

## The 5,000 item view threshold

A list can hold millions of items. A *view* that would return more than
5,000 fails. This is the single most misunderstood SharePoint limit, so be
precise about it.

Fixes, in order of preference: index the filtered column, filter the view
so it returns under 5,000, add folders or a metadata partition, page the
results. Not a fix: asking Microsoft to raise it.

## Power Fx and delegation

Delegation is the reason a working app breaks in production.

Non-delegable operations run against the first 500 rows (default, up to
2,000) and silently give wrong answers on a larger list. No error appears.

Delegable against SharePoint: `Filter`, `Search`, `LookUp`, `Sort`,
`SortByColumns` with the supported operators.

Not delegable against SharePoint: `Search` on some column types, `in`,
`CountRows` on a filtered set, most functions applied to a calculated
column, and anything on a multi-value column.

When a formula is not delegable, Power Apps shows a blue underline
warning. Treat it as an error, not a suggestion.

## Power Automate

**Connection ownership is the usual failure.** A flow runs as the
connection owner. When that person leaves, the flow breaks. Check
`conventions.md` for whether a service account is standard.

**Trigger conditions, not a condition action.** A flow that triggers on
every change and then decides to do nothing still consumes runs.

**The trigger fires on item creation and modification**, including
modification by the flow itself. Infinite loops are easy to write.

**Error handling.** Configure run-after on the failure path. A flow that
fails silently is worse than no flow.

## Formatting

JSON column and view formatting is the supported way to change appearance.
It is declarative, it does not require deployment, and it survives
upgrades. Prefer it over any code approach for appearance.

## Executing

Route every read and write through `tenant-ops`.

## Reference

- `references/list-schema-patterns.md`
- `references/thresholds-and-limits.md`
- `references/power-fx-delegation.md`
- `references/flow-patterns.md`
- `references/json-formatting.md`
