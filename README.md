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
`tenant/` and never leave your machine. Answers draw on both.

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

## Your tenant data stays private

This repository is public. The knowledge base is meant to be shared. Your
tenant configuration is not.

`tenant/` is listed in `.gitignore`. Site inventories, permission maps,
group memberships, and license details never get committed. What is
committed is a set of templates:

```
tenant/profile.example.md        Copy to tenant/profile.md and fill in
tenant/conventions.example.md    Copy to tenant/conventions.md and fill in
```

Before your first commit, confirm `git status` does not list anything
under `tenant/` other than the examples. A site inventory pushed to a
public repository is a reconnaissance document for anyone who wants one.

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

The skills follow the open Agent Skills specification: a directory per
skill, each with a `SKILL.md` carrying YAML frontmatter, plus optional
`references/`, `scripts/`, and `assets/` subdirectories. That format is
consumed by Claude Code, OpenAI Codex CLI, GitHub Copilot, Cursor, Gemini
CLI, and Microsoft Agent Framework, among others.

Project instructions live in `AGENTS.md`, the cross-tool standard.
`CLAUDE.md` exists as a one-line import of `AGENTS.md` so there is exactly
one source of truth. Claude Code v2.1.277 and later can read `AGENTS.md`
directly, but the import works on every version.

Skills are stored in `.claude/skills/` because that is where Claude Code
discovers them without configuration. The content is tool-neutral. Other
agents that use a different discovery path can be pointed at that
directory or given a copy.

Nothing here depends on a specific model or vendor.

## Repository layout

```
AGENTS.md              Project instructions. Scope, safety contract, tenant pointer.
CLAUDE.md              One line: imports AGENTS.md.
.claude/skills/        The skills. Organized by task, not by certification.
knowledge/
  sharepoint/          Generic SharePoint Online knowledge.
  _shared/             Licensing, Entra identity, Graph, admin centers.
tenant/                Gitignored except the examples. Your tenant's facts.
  profile.example.md
  conventions.example.md
scripts/
  read/                Inspection and reporting.
  write/               Change operations, called only via tenant-ops.
```

Skills are organized by the task a user brings, not by how the knowledge
was sourced. Nobody asks for help with "a PL-400 problem." They ask why a
flow keeps hitting a delegation warning.

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

**Every write is logged.** `tenant/inventory/changelog.md` records the
timestamp, what changed, and the rollback command.

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
specific licenses. Until a tier is recorded in `tenant/profile.md`,
governance advice stays inside features available at every tier.

## Setup

1. Secure the administrative roles listed above.
2. Clone the repository.
3. Copy `tenant/profile.example.md` to `tenant/profile.md`.
4. Ask the agent to inspect the tenant and fill in the profile, starting
   with the license tier.
5. Copy `tenant/conventions.example.md` to `tenant/conventions.md` and
   record the standards you intend to hold to. This file is the one that
   makes Oracle365 yours rather than generic.

Tenant access needs a connector or credential the agent can use. A
read-only Microsoft 365 connector covers inspection. Writes need Microsoft
Graph with an app registration, or PnP PowerShell run from a machine that
can reach Graph. Cloud-hosted agent sessions are often network-restricted
and cannot reach `graph.microsoft.com`, so the write path usually runs
locally.

## Status

Early. The structure is settled, content is being written.

Order of work:

1. `AGENTS.md` and the safety contract
2. `tenant/` templates and `.gitignore`
3. The read path, so inventory is generated rather than typed
4. Governance and architecture skills, the daily-use ones
5. Build, dev, and triage skills
6. The write path, once the read path has proven the tenant model is right

## License

See `LICENSE`.
