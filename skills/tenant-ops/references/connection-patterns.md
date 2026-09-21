# Connection patterns

How to connect, which identity to use, and what the common failures
actually mean.

Verified against PnP PowerShell documentation, dev branch, 2026-09-21.

## Choosing the identity

| You need to | Use | Why |
|---|---|---|
| List sites, audit the tenant, read licensing | Delegated | Tenant-wide reads are impossible under `Sites.Selected` |
| Read or write one granted site | App-only | No human in the loop, scope is the per-site grant |
| Run on a schedule | App-only | Delegated needs a person at a browser |
| Anything you are unsure about | Delegated | It cannot exceed the roles you already hold |

Default to delegated. It fails safe: whatever you get wrong, you could
have done by hand in the admin center anyway.

## App-only, certificate

```powershell
Connect-PnPOnline -Url https://contoso.sharepoint.com/sites/finance `
  -ClientId   <client_id> `
  -Tenant     contoso.onmicrosoft.com `
  -Thumbprint <certificate_thumbprint> `
  -ValidateConnection
```

Values come from `profile.md`. Never prompt someone to paste a thumbprint
into a conversation when it is already on disk.

A client secret does not work here. Entra does not support secrets for
SharePoint CSOM and REST, whatever it allows for Graph. If you find a
script using `-ClientSecret` against SharePoint, it is either legacy ACS
or it does not work.

`-ValidateConnection` makes a test request rather than just building a
context, so a bad thumbprint fails at connect rather than three cmdlets
later.

## Delegated, interactive

```powershell
Connect-PnPOnline -Url https://contoso-admin.sharepoint.com `
  -ClientId <client_id> `
  -Interactive `
  -ValidateConnection
```

`-ClientId` has been required since 9 September 2024. The multi-tenant PnP
Management Shell app that used to make it optional is gone. Alternatively
set `ENTRAID_APP_ID` or `ENTRAID_CLIENT_ID` in the environment and PnP
picks it up.

Over SSH, or anywhere a browser cannot open, use `-DeviceLogin` instead of
`-Interactive`.

## Which URL

| Operation | Connect to |
|---|---|
| `Get-PnPTenantSite`, `Get-PnPTenant`, `Get-PnPExternalUser` | The admin URL, `https://<tenant>-admin.sharepoint.com` |
| Anything inside a site: lists, groups, permissions | That site's URL |

Connecting to a site URL and then calling a tenant cmdlet fails in a way
that reads like a permissions problem. Check which URL you are on first.

## Failures and what they mean

**"Attempted to perform an unauthorized operation"** on a tenant cmdlet,
app-only. The grant is `Sites.Selected` and the operation needs tenant
admin. Reconnect delegated. Do not widen the application grant.

**The same error against a specific site**, app-only. That site has not
been granted. Fix it with one grant:

```powershell
Grant-PnPEntraIDAppSitePermission `
  -AppId <client_id> -DisplayName Oracle365 `
  -Permissions Read -Site https://contoso.sharepoint.com/sites/finance
```

`-DisplayName` must match the app registration name exactly.

**Consent errors on PnP operations when Graph calls work.** `Sites.Selected`
exists separately on the SharePoint API and the Graph API. PnP CSOM needs
the SharePoint one. Granting only Graph produces exactly this.

**`AADSTS700027` or certificate errors.** The certificate has expired, or
it is not in the store this account can read. Certificates created by
`Register-PnPEntraIDApp` default to a fixed lifetime and expire silently.
An expired certificate fails as an authentication error that looks like a
permissions problem.

**`-Interactive` fails with a missing client id.** See above. Since
September 2024 it is required.

**429, or "request has been throttled".** Honor `Retry-After`. Back off
exponentially. Do not retry immediately in a loop, which extends the
throttling window. `Invoke-Oracle365Throttled` in `scripts/lib` paces
per-item work for this reason.

## Disconnecting

`Disconnect-PnPOnline` ends the session. Worth doing in a script that
switches identity partway through, because PnP holds the connection in
module state and a stale context produces confusing failures.

## What never goes in a script

A certificate file path with a password. A client secret. A password. A
token. The certificate lives in the OS certificate store and the script
carries the thumbprint, which is an identifier.

If you see a secret in output, do not echo it back and do not write it
anywhere. Say where it appeared.
