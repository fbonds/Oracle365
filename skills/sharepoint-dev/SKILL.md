---
name: sharepoint-dev
description: Develop custom code against SharePoint Online. Use for SharePoint Framework web parts and extensions, Microsoft Graph queries and permissions, Entra ID app registration and authentication, PnP PowerShell and PnP Core SDK, REST and CSOM, Teams apps backed by SharePoint, and deployment through the app catalog. Triggers on SPFx, web part, extension, Graph, API, app registration, authentication, token, scope, PnP, REST, CSOM, Teams app, app catalog, deploy, SDK.
---

# SharePoint development

Custom code against SharePoint Online. Reach for this only after
establishing that configuration, JSON formatting, and Power Platform
cannot do the job. Custom code is the most expensive option to maintain,
and in a small organization it is usually maintained by nobody.

## Order of operations

1. Read `conventions.md` for whether custom code is permitted, the
   approval process, and where source lives.
2. Read the app registration section of `profile.md`. Do not create a
   second registration when one exists.
3. Check the permission model. Under `Sites.Selected`, code that works in
   development against a granted site will fail elsewhere.

## Authentication

Certificate-based app-only for anything unattended. Entra does not support
a client secret for SharePoint CSOM and REST. This surprises people who
have used secrets successfully against Graph.

Delegated auth acts as the signed-in user and is bounded by their
permissions. App-only acts as the application and is bounded only by its
grant. Be explicit about which one a piece of code uses, because the
security properties are entirely different.

Never write a credential into source. The certificate lives in the OS
certificate store. Source carries the thumbprint.

## Graph permissions

Request the narrowest scope that works. `Sites.Selected` plus explicit
per-site grants is the recommended default and should be the starting
assumption.

Escalating to `Sites.ReadWrite.All` or `Sites.FullControl.All` is a
decision that needs recording in `profile.md` with a justification, not a
convenience.

Application permissions require admin consent. Delegated permissions may
or may not, depending on the scope and tenant settings.

## SPFx

Version compatibility between SPFx, Node, and TypeScript is strict and a
mismatch produces confusing errors. Check the current support matrix
rather than assuming; it moves.

Web part for something users place on a page. Extension for something that
applies automatically: application customizer for page-level chrome, field
customizer for column rendering, command set for list commands.

Before writing an SPFx web part, check whether JSON formatting or an
embedded Power App does it. Most requests that arrive as "we need a web
part" do not.

Deployment goes through the tenant app catalog, which must exist. Scoping
to a site collection app catalog limits blast radius during testing.

## Throttling

SharePoint throttles aggressively and will not warn you first. Honor
`Retry-After`. Implement exponential backoff. Batch requests. Set a
meaningful User-Agent string, which Microsoft uses to decide how hard to
throttle you.

Code that works against a test site with 50 items will be throttled
against a real library. Assume it.

## Executing

Route every read and write through `tenant-ops`.

## Reference

- `references/spfx.md`
- `references/graph-queries.md`
- `references/auth-and-app-registration.md`
- `references/pnp-powershell.md`
- `references/throttling-and-limits.md`
