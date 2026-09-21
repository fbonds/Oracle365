# Conventions

Copy this file to your Oracle365 config directory as `conventions.md` and
fill it in.

```
Linux/macOS:  ~/.config/oracle365/conventions.md
Windows:      %APPDATA%\Oracle365\conventions.md
```

This is the file that makes Oracle365 yours rather than generic. Without
it every answer is a textbook answer. An empty section is not a problem:
it is an honest statement that no standard exists yet, and Oracle365 will
say so rather than inventing one.

Record the rule and the reason. A rule without a reason gets broken the
first time it is inconvenient.

---

## Naming

- **Sites:**
- **Hubs:**
- **Libraries:**
- **Lists:**
- **Content types:**
- **Entra groups:**
- **Power Automate flows:**
- **Power Apps:**

## Site lifecycle

- **Who may request a site:**
- **Who approves:**
- **Required metadata at creation:**
- **Owner count required:** (two is the usual minimum, so departure does
  not orphan a site)
- **Review cadence:**
- **Archive policy:**
- **Deletion policy:**

## Permissions

- **Default model:** (inherit from hub, unique per site, other)
- **When unique permissions are acceptable:**
- **Who may grant access:**
- **Group-based or direct:**
- **Guest and external access rules:**
- **Review cadence:**

## Sharing

- **External sharing stance:**
- **Anonymous link policy:**
- **Link expiration:**
- **Sites with stricter rules than the tenant default:**

## Content

- **What belongs in SharePoint versus elsewhere:**
- **Retention expectations:**
- **Sensitive content handling:**
- **Versioning settings:**

## Lists and data

- **When a SharePoint list is the right answer:**
- **When it is not:** (list view threshold, relational needs, volume)
- **Required columns on every list:**
- **Indexing standards:**

## Automation

- **Who may create flows:**
- **Service account or named account:**
- **Connection ownership:** (flows owned by an individual break when they
  leave)
- **Error handling expectations:**
- **What must not be automated:**

## Development

- **SPFx permitted:**
- **Approval process for custom code:**
- **Source control location:**
- **Deployment process:**

## Non-negotiables

Rules that must never be broken without a written decision. Oracle365
treats a proposal that violates one of these as requiring explicit
override, not routine approval.

-
