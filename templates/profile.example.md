# Tenant profile

Copy this file to your Oracle365 config directory as `profile.md` and
fill it in. It does not belong in the repository.

```
Linux/macOS:  ~/.config/oracle365/profile.md
Windows:      %APPDATA%\Oracle365\profile.md
```

Nothing in this file is a secret. Client ID, tenant ID, and certificate
thumbprint are identifiers. The certificate private key lives in the OS
certificate store and never appears here.

---

## Identity

- **tenant_name:**
- **tenant_id:**
- **primary_domain:**
- **sharepoint_root:** `https://<tenant>.sharepoint.com`
- **admin_url:** `https://<tenant>-admin.sharepoint.com`

## App registration

- **client_id:**
- **certificate_thumbprint:**
- **certificate_location:** CurrentUser\My
- **created_by:**
- **created_on:**

## Graph permissions granted

State the actual grant, not the intended one.

- **permission_model:** `Sites.Selected` | `Sites.ReadWrite.All` | `Sites.FullControl.All`
- **justification (required if not Sites.Selected):**

### Sites granted under Sites.Selected

| Site URL | Access level | Granted on | Reason |
|---|---|---|---|
| | read / write / manage / fullcontrol | | |

## Licensing

This field gates what can be recommended. Leave it `unknown` rather than
guessing.

- **license_tier:** unknown
- **verified_on:**

Feature availability, filled in once the tier is known:

| Feature | Available | Notes |
|---|---|---|
| Sensitivity labels | unknown | |
| Purview retention | unknown | |
| Data Loss Prevention | unknown | |
| Conditional Access | unknown | |
| Premium Power Platform connectors | unknown | |
| Dataverse | unknown | |
| SharePoint Premium | unknown | |

## Tenant settings

- **external_sharing_default:**
- **default_link_type:**
- **default_link_permission:**
- **site_creation:** who can create sites
- **storage_model:** pooled or per-site quota

## Site topology

| Site | URL | Type | Hub | Owner role | Notes |
|---|---|---|---|---|---|
| | | team / communication / hub | | | |

## Administrative roles held

Which roles the operator of this tool actually has. Determines what is
possible versus advisory.

- [ ] Global Reader
- [ ] SharePoint Administrator
- [ ] Power Platform Administrator
- [ ] Compliance Administrator
- [ ] Global Administrator

## Known exceptions

Places where reality deliberately departs from the conventions, and why.
Without this, every audit rediscovers the same false positives.

| What | Where | Why | Decided by | Date |
|---|---|---|---|---|
| | | | | |
