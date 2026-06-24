# 07. Claude Code's Plane MCP

Docs 01–06 cover driving Plane through the **shell CLI** (`plane-cli-requiem`). This doc covers
the other path: the **official Plane MCP server**, used from **Claude Code**.

> When to read this: you're already in Claude Code (or another MCP client) and want Plane as a set
> of structured tools instead of shell commands — explicit schemas, fewer wrong arguments, and a
> query language (PQL) the CLI doesn't have.

---

## 1. CLI vs MCP — pick by the job

| | CLI (`plane-cli-requiem`) | MCP (Plane MCP server) |
|---|---|---|
| Shape | Shell command, text in/out | Structured tool call, typed args |
| Compose with pipes (`\| jq`) | ✅ Strong | ❌ Weak (no shell) |
| Argument safety | Agent assembles flags | ✅ Schema-validated |
| Querying | `plane ls` + jq filtering | ✅ **PQL** (`type = "Epic"`, `childOf("PROJ-12")`) |
| Setup | `cargo install`, env var | Register a server with the MCP client |
| Best for | Quick shell automation, scripts | Many agents, strict schemas, rich queries |

They are **complementary, not exclusive.** A common split: MCP for structured reads and creates
inside Claude Code, CLI for quick one-off shell pipelines.

---

## 2. How Claude Code sees MCP tools

Once a Plane MCP server is registered, its tools appear to the agent namespaced as:

```
mcp__plane__<tool>
```

For example `mcp__plane__list_work_items`, `mcp__plane__create_work_item`,
`mcp__plane__list_projects`. This naming matters for two reasons:

- It's how you **scope permissions** (section 5) — the same allowlist mechanism that gates Bash.
- It tells the agent which server a tool belongs to, so multiple MCP servers don't collide.

Type `/mcp` inside Claude Code to see connected servers, their status, and (for OAuth servers) to
authenticate.

---

## 3. Register the server in Claude Code

The Plane MCP server speaks HTTP. Add it with `claude mcp add`:

```bash
# Official hosted Plane MCP (cloud workspaces)
claude mcp add --transport http plane https://mcp.plane.so/mcp

# For a self-hosted instance, point at your own MCP endpoint instead, e.g.:
#   claude mcp add --transport http plane https://plane.bit-habit.com/mcp
# Confirm the exact path against your Plane version's MCP docs — self-hosted MCP support
# and its URL/auth can differ from the cloud one.
```

**Scopes** decide who sees the server:

- `--scope local` (default): just you, just this project
- `--scope project`: committed to `.mcp.json` so teammates get it too (no secrets in it!)
- `--scope user`: all your projects on this machine

A `.mcp.json` (project scope) looks like:

```json
{
  "mcpServers": {
    "plane": {
      "type": "http",
      "url": "https://mcp.plane.so/mcp"
    }
  }
}
```

Verify:

```bash
claude mcp list          # shows registered servers
# then inside Claude Code:  /mcp
```

---

## 4. Auth

The Plane MCP authenticates per its own flow — typically **OAuth** (run `/mcp` and follow the
login) for the hosted server, or an **API key** for self-hosted/headless setups (often passed as
a header).

```bash
# Example: API-key header at registration time (confirm the header name in Plane's MCP docs)
claude mcp add --transport http plane https://plane.bit-habit.com/mcp \
  --header "X-API-Key: plane_api_xxx"
```

> Same rule as the CLI token (docs 03–06): **least privilege, short expiry, never commit it.**
> Don't put a key inside a project-scoped `.mcp.json` that gets committed — use a local/user scope
> or an environment reference instead.

---

## 5. Guardrails — scope what the agent may call

MCP tool calls go through the same permission system as everything else in Claude Code. You allow
tools by their `mcp__plane__*` name in `.claude/settings.json`:

- Allow a single tool: `"mcp__plane__list_work_items"`
- Allow the whole server: `"mcp__plane"` (everything — broad; use carefully)

The safe pattern mirrors doc 04: **allow reads freely, gate writes behind confirmation.** Reads
(`list_*`, `retrieve_*`, `get_*`, `search_*`, `count_*`) are low-risk; writes
(`create_*`, `update_*`, `delete_*`, `manage_*`) should not be blanket-allowed.

Below is the allowlist that ships in this doc. The read tools are filled in; **the write-side
policy is left for you to decide** — see the `TODO(human)` in `.claude/settings.json` style below:

```jsonc
// .claude/settings.json  (permissions excerpt)
{
  "permissions": {
    "allow": [
      "mcp__plane__list_projects",
      "mcp__plane__list_work_items",
      "mcp__plane__retrieve_work_item",
      "mcp__plane__search_work_items",
      "mcp__plane__list_work_item_comments"
      // TODO(human): decide the write-side policy.
      //   Which (if any) mcp__plane__ write tools go in "allow" vs "ask"/"deny"?
      //   e.g. allow create_work_item_comment, but keep delete_* out of "allow".
    ]
    // "ask" / "deny" lists can mirror the same naming.
  }
}
```

---

## 6. Key conventions the agent should know

The Plane MCP server centers on **work items** (issues), and ships its own usage instructions.
Two conventions trip agents up:

**PQL (Plane Query Language)** — `list_work_items` takes a `pql` filter, not ad-hoc flags:

```
list_work_items(project_id, pql='type = "<type id>"')
list_work_items(project_id, pql='childOf("PROJ-12")')   # children of an epic by identifier
```

Call `get_pql_reference` when unsure of the syntax.

**Epics** — there is no "epic" tool. An epic is just a work item whose **type** is named "Epic":

```
1. type = resolve_work_item_type(project_id, "Epic")        # type.id is the type_id
2. create_work_item(project_id, type_id=type.id, name=...)   # create the epic
3. list_work_items(project_id, pql='childOf("PROJ-12")')     # its children, by identifier
4. set parent=<work item id> on a child to nest it under the epic
```

A work item always belongs to a project — resolve/ask for the `project_id` first
(`list_projects`).

---

## 7. Common tools (read vs write)

| Intent | Tool |
|--------|------|
| List projects | `list_projects` |
| List issues (with PQL) | `list_work_items` |
| Read one issue | `retrieve_work_item` / `retrieve_work_item_by_identifier` |
| Search issues | `search_work_items` |
| Read comments | `list_work_item_comments` |
| Create an issue | `create_work_item` |
| Update an issue | `update_work_item` |
| Comment on an issue | `create_work_item_comment` |
| Assign / label | `manage_work_item_assignee` / `manage_work_item_label` |
| Cycles / modules | `create_cycle`, `list_cycles`, `manage_cycle_work_items`, `manage_module_work_items` |

> Note the contrast with doc 06: the CLI **can't create cycles** (a known bug needing a raw-API
> workaround), but the MCP server exposes `create_cycle` directly. Where the CLI has gaps, MCP is
> often the cleaner path — and vice versa.

---

## 8. Quick verify (inside Claude Code)

1. `/mcp` → confirm `plane` is **connected** (authenticate if prompted).
2. Ask the agent to call `list_projects` → you should get structured project data back.
3. Ask for `list_work_items` on one project with `pql='type = "Epic"'` → confirms PQL works.
4. Only after reads work, test a single low-risk write (e.g. `create_work_item_comment`) behind
   your confirmation policy from section 5.

Reads first, writes behind a gate — the same boundary as the CLI path
([04-ai-agent-integration.md](04-ai-agent-integration.md#guardrails)).
