# Oracle365

A narrowly focused SharePoint Online expert, packaged as a portable agent
skill set.

Oracle365 gives an AI coding agent two things it does not have on its own:
SharePoint Online knowledge organized for retrieval, and a written record
of how your specific tenant is actually configured. It can inspect a live
tenant and change it, but only after a human approves each change.

It is built for organizations of roughly tens to low hundreds of users
running dozens of sites: clubs, nonprofits, small businesses, departments
inside larger organizations. Nothing in it is specific to any one tenant.

## Administrative access is required

Read this before anything else. Oracle365 is not useful without tenant
administrative rights, and there is no way to work around that.

| Capability | Minimum role |
|---|---|
| Inspect sites, permissions, settings | Global Reader |
| Site and hub administration, sharing policy, storage | SharePoint Administrator |
| Flow and app governance, environment settings | Power Platform Administrator |
| Retention, sensitivity labels, DLP | Compliance Administrator or a Purview role |
| One-time consent for a Microsoft Graph app registration | Global Administrator |

Roles are assigned in Microsoft Entra ID.

Without at least Global Reader, Oracle365 is a reference book. It can
explain SharePoint and reason about what you describe to it, but it cannot
see your tenant, so it cannot tell you whether its advice fits.

Without SharePoint Administrator, it is advisory only. It will draft the
commands. Somebody with the role has to run them.

If you are setting this up for an organization where you are not the
administrator, secure the roles first. Building the knowledge base before
you have access produces something that sounds authoritative and cannot
be verified against reality.

## Why this exists

Small organizations run on SharePoint and rarely document it. Decisions
about sites, permissions, lists, and automation get made by whoever is
available, and the reasoning is rarely written down. Six months later
nobody remembers why a library has unique permissions or what the naming
convention was supposed to be.

A general-purpose AI assistant knows SharePoint in general. It does not
know that your finance site inherits from a hub, that external sharing is
disabled for member records, or which license tier you pay for. Without
that, its advice is plausible and frequently wrong for you.

Oracle365 separates the two. Generic SharePoint knowledge lives in
`knowledge/` and ships with the repository. Your tenant's facts live in
your OS config directory and never leave your machine. Answers draw on
both.

## Scope

In scope:

- SharePoint Online, modern experience
- Site and hub architecture, information architecture
- Permissions, sharing, lifecycle, and governance
- Lists, Power Apps, and Power Automate built on SharePoint data
- SPFx, Microsoft Graph, and Teams apps that touch SharePoint
- Troubleshooting: access problems, search, sync, sharing links, migration

Out of scope:

- SharePoint Server on-premises. Cloud only.
- Teams, Exchange, Entra, and Power Platform as subjects in their own
  right. They appear only where they intersect SharePoint.

The layout allows those other workloads to be added later without
restructuring.

## Where your tenant data lives

Not in this repository. Not anywhere inside it.

A gitignored file in the repo would be the weak option: `.gitignore` is one
edit from failing, `git add -f` bypasses it, and the file still sits in a
folder that backup and sync tools sweep whole. Oracle365 keeps tenant data
out of the repository entirely, using the convention `aws`, `gh`, `kubectl`,
and `az` all follow.

**Configuration** goes in the OS config directory:

```
Linux/macOS:  ~/.config/oracle365/
Windows:      %APPDATA%\Oracle365\
```

It holds `profile.md` (tenant identifiers, license tier, granted sites) and
`conventions.md` (your standards). Override the location with
`ORACLE365_CONFIG_DIR`.

**Credentials** are never in a file at all. SharePoint app-only access in
Entra requires a certificate; a client secret is not supported for
SharePoint CSOM and REST. Setup creates a self-signed certificate directly
in your OS certificate store, and the private key stays there. Your config
holds the client ID, tenant ID, and certificate thumbprint, which are
identifiers rather than secrets.

**Regenerable inventory** goes in the cache directory (`~/.cache/oracle365/`
or `%LOCALAPPDATA%\Oracle365\`), so deleting it is always safe.

The repository holds templates and instructions. There is nothing in it to
leak.

One design rule follows from this: configuration stores conventions and
pointers, never data. Site URLs and naming rules, yes. Member lists, no.
Anything genuinely sensitive is read live from the tenant when needed and
not kept at rest.

## Least privilege

The recommended grant is `Sites.Selected` on both the SharePoint and the
Microsoft Graph APIs, with access granted explicitly per site collection.

Both are needed, and this catches people out. `Sites.Selected` exists
separately on each API. PnP PowerShell's CSOM operations and
`Grant-PnPEntraIDAppSitePermission` depend on the SharePoint API
permission. Graph-based reads depend on the Graph one. An app granted only
Graph `Sites.Selected` will fail in PnP with errors that look like a
consent problem.

This is a hard technical boundary rather than a policy. With
`Sites.Selected`, the tool cannot reach a site that has not been granted,
regardless of what any prompt, skill, or instruction says. The approval
protocol below becomes a second line of defense instead of the only one.

Tenant-wide application grants such as `Sites.FullControl.All` are treated
as an exception requiring written justification in your profile.

There is a limit to this, and the design accounts for it rather than
pretending otherwise. `Sites.Selected` can inspect a site it has been
granted, but it cannot discover one. Site enumeration needs SharePoint
Administrator, and reading licensing needs a Graph licensing permission.
Neither is possible app-only under `Sites.Selected`.

So Oracle365 uses two identities. Tenant-wide reads run **delegated**, as
the signed-in administrator, bounded by the roles that person actually
holds. Writes and automation run **app-only** against explicitly granted
sites. Nothing that can read the whole tenant runs unattended, and a stolen
certificate cannot enumerate anything it was not granted.

Scripts take `-Mode Delegated` or `-Mode AppOnly` and default to delegated.

## Using it

Open the repository in your agent and ask a question in plain language.
The relevant skill loads based on what you asked.

```
"Why can't the committee see the membership library?"
"Design a list schema for equipment bookings."
"What happens to the sites owned by a member who leaves?"
"Audit which sites have external sharing turned on."
```

You do not invoke skills by name. Ask the question you have.

Anything that changes the tenant stops for approval first.

## Agent compatibility

Skills follow the open Agent Skills specification: a directory per skill,
each with a `SKILL.md` carrying YAML frontmatter, plus `references/`,
`scripts/`, and `assets/` subdirectories. That format is consumed by Claude
Code, OpenAI Codex CLI, GitHub Copilot, Cursor, Gemini CLI, and Microsoft
Agent Framework, among others.

Skills live in `skills/` at the repository root. `.claude/skills` is a
symlink to it, so Claude Code discovers them with no configuration while the
canonical location stays vendor-neutral. If your platform does not support
symlinks in git, point your agent at `skills/` directly.

Project instructions live in `AGENTS.md`, the cross-tool standard.
`CLAUDE.md` is a one-line import of it, so there is exactly one source of
truth. Claude Code v2.1.277 and later reads `AGENTS.md` natively, but the
import works on every version.

Nothing here depends on a specific model or vendor.

## Repository layout

```
AGENTS.md              Operating instructions. Safety contract, config resolution, routing.
CLAUDE.md              One line: imports AGENTS.md.
skills/                Six skills, organized by task. Canonical location.
.claude/skills         Symlink to skills/ for Claude Code discovery.
knowledge/
  sharepoint/          Generic SharePoint Online knowledge.
  _shared/             Licensing, Entra identity, Graph, admin centers.
templates/             profile.example.md, conventions.example.md.
scripts/
  lib/                 Shared: path resolution, profile parsing, connection.
  setup/               First-run setup.
  read/                Inspection and reporting.
  write/               Change operations, called only via tenant-ops.
```

No `tenant/` directory. That is the point.

Skills are organized by the task a user brings, not by how the knowledge was
sourced. Nobody asks for help with "a PL-400 problem." They ask why a flow
keeps hitting a delegation warning.

| Skill | Handles |
|---|---|
| `sharepoint-architecture` | Site and hub topology, information architecture, list vs library vs Dataverse |
| `sharepoint-governance` | Permissions, sharing, lifecycle, retention, labels, sprawl |
| `sharepoint-build` | Lists, Power Apps, Power Automate, Power Fx, formatting, delegation |
| `sharepoint-dev` | SPFx, Graph, app registration, Teams apps, PnP |
| `sharepoint-triage` | Something is broken now: access, search, sync, links, migration |
| `tenant-ops` | Every operation that reads from or writes to the live tenant |

## Safety contract

Enforced in `AGENTS.md` and in the `tenant-ops` skill, which is the only
skill permitted to touch the tenant.

**Reads run freely.** Inspecting sites, listing permissions, reading
settings, and generating reports need no approval.

**Writes require explicit approval, every time.** Before any change,
Oracle365 shows:

1. The target resource
2. Its current state
3. The proposed state
4. Blast radius: who and what else is affected
5. The command that reverses it

Nothing runs until a human says so. Approving one change does not approve
the next.

**Every write is logged.** `changelog.md` in the cache directory records
the timestamp, what changed, and the rollback command.

**Bulk operations get a dry run.** Anything touching more than ten objects
produces a full dry-run report first. Adjust the threshold in `AGENTS.md`.

## Knowledge sources

The knowledge base covers the ground tested by the Microsoft 365
Fundamentals, Microsoft 365 Administrator, Power Platform App Maker, and
Power Platform Developer certifications, plus the SharePoint and Graph
development material formerly covered by MS-600.

Exam codes are a coverage checklist, never a structure. They change.
MS-600 retired in March 2023. MS-102 retires in November 2026. Each folder
under `knowledge/` carries a `source.md` recording where its content came
from and when it was last checked, so stale material is visible rather
than silently trusted.

License tier gates what can be recommended. Sensitivity labels, Purview
retention, DLP, and premium Power Platform connectors each sit behind
specific licenses. Until a tier is recorded in `profile.md`,
governance advice stays inside features available at every tier.

## Setup

1. Secure the administrative roles listed above. Without them this is a
   reference book.

2. Clone the repository and install PnP PowerShell:

   ```powershell
   Install-Module PnP.PowerShell -Scope CurrentUser
   ```

3. Review `scripts/setup/Initialize-Oracle365.ps1`, then run it. It creates
   the config directory, copies the templates, and registers an Entra ID
   application with a certificate in your OS certificate store.

   ```powershell
   ./scripts/setup/Initialize-Oracle365.ps1 -Tenant contoso.onmicrosoft.com -WhatIf
   ```

   Run with `-WhatIf` first. It creates an app registration in your tenant,
   which needs Global Administrator consent. Use `-SkipAppRegistration` if
   one already exists.

4. Grant the app access to each site it needs, one at a time:

   ```powershell
   Grant-PnPEntraIDAppSitePermission `
     -AppId <client_id> `
     -DisplayName Oracle365 `
     -Permissions Read `
     -Site https://<tenant>.sharepoint.com/sites/<site>
   ```

   `-DisplayName` must match the app registration name exactly.
   `-Permissions` accepts Read, Write, Manage, or FullControl. Start at
   Read and raise it when something actually needs it.

5. Fill in `profile.md`, starting with `license_tier`. It gates what can be
   recommended.

6. Fill in `conventions.md`. This is the file that makes Oracle365 yours
   rather than generic. An empty section is honest; an invented one is not.

7. Open the repository in your agent and ask it to verify the connection.

The write path needs a machine that can reach `graph.microsoft.com`.
Cloud-hosted agent sessions are often network-restricted, so writes usually
run locally while reads can run anywhere a connector reaches.

## Status

Scaffolded. The structure, the safety contract, and the setup path are
complete. The knowledge base is not written.

In place:

- `AGENTS.md` with the full safety contract, config resolution, license
  gating, and skill routing
- Six skills with working descriptions and real decision content
- Configuration and conventions templates
- First-run setup script with `-WhatIf` support

- `knowledge/_shared/licensing.md`, the gate every recommendation passes
  through, with per-claim sources and verification dates
- A read path: licensing and tenant settings, site inventory, permissions
  audit, sharing report, over a shared library handling paging, throttling
  and snapshot stamping

Not written, and marked as such in the files themselves:

- Every file under `skills/*/references/`. Each carries a "not yet written"
  header so nothing is presented as authoritative by accident.
- `knowledge/sharepoint/`

`AGENTS.md` requires any answer drawing on unwritten or stale material to
say so. A placeholder that announces itself is safe. A placeholder that
looks like content is not.

No script here has been executed. They were written against current PnP
PowerShell documentation and checked structurally, not run.

Next:

1. Run setup against a real tenant, then the read scripts, and fix what
   breaks. Nothing is trustworthy until this happens.
2. Write the `tenant-ops` references, since everything routes through them
3. Write the governance and triage references, the daily-use ones
4. Fill `knowledge/sharepoint/` from current Microsoft documentation

## License

See `LICENSE`.
