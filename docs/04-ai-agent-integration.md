# 04. AI agent integration

Goal: expose the same `plane` CLI a human uses **directly as a tool for an AI agent**, so the
agent can read, create, and comment on issues — safely.

## Two integration paths

### A) Expose the CLI as the agent's shell tool (simplest)

Most coding agents (e.g. Claude Code) can run shell commands. In an environment where
`PLANE_API_URL` and a token are set, the agent just uses it directly:

```bash
plane mine items --format json
plane ls --project <slug> --format json
plane create "Issue title" --project <slug> --description "..."
plane comment post <NRO-123> "comment body"
```

> Real command names (plane-cli-requiem v0.3.3):
> - Read: `plane ls`, `plane show <ID>`, `plane mine items`, `plane projects`, `plane me`,
>   `plane comment ls <ID>`, `plane dashboard`
> - Write: `plane create <title>`, `plane update <ID> --state ...`, `plane done <ID>`,
>   `plane comment post <ID> "..."`, `plane bulk <ID...>`, `plane delete <ID>`
> - Output is JSON automatically when piped (`--format json` may be stated explicitly).

What to tell the agent in the system prompt:

- **Always add `--format json`** (deterministic parsing).
- **Get human confirmation before write commands (`create`/`update`/`delete`).**
- Use only the allowed subcommands (the whitelist below).

### B) MCP (Model Context Protocol)

With the official **Plane MCP Server**, Plane is exposed as structured MCP tools instead of the
CLI. The schemas are explicit, so the agent gets arguments wrong less often. It can complement or
replace the CLI path.

- Pros: tool schemas and permissions are explicit; output is structured
- Cons: a separate server to run; weaker shell composability (pipes)
- How to choose: **quick shell automation → CLI**, **many agents / strict schemas → MCP**

For using the Plane MCP from Claude Code specifically, see
[07-claude-code-plane-mcp.md](07-claude-code-plane-mcp.md).

You can also build a **thin MCP wrapper** around `plane-cli-requiem` yourself, registering only
the allowed commands as tools (the composability of the CLI + the explicitness of MCP).

## Guardrails

The minimum measures to keep an agent from breaking Plane:

### 1) Least-privilege token + short expiry

- **Separate** the agent-only token from the human's token.
- Start **read-first** where you can (query/summarize). Add writes once trust builds.
- Set a **short expiry** and rotate periodically.
- Inject the token only via env var / secrets manager. **Never leave it in a prompt, log, or
  commit.**

### 2) Command whitelist

Explicitly limit the subcommands the agent may call. For example:

```
Allow (read):   plane me, plane projects, plane ls, plane mine items, plane show
Allow (write):  plane comment post       # comments are relatively safe
Deny:           plane delete --yes, plane bulk, bulk update
```

If you use a read-only token, the server blocks again even if the whitelist is breached (defense
in depth).

### 3) Human-in-the-loop

Run write operations as **propose → human approval → execute**. A safe pattern: the agent only
prints the command it would run, and only what the human approves is passed to the shell.

### 4) Change tracking

Tag issues the agent creates or changes with a consistent label (e.g. `agent`) or a comment
signature, so a human can filter and roll them back later.

## Example agent loop (pseudocode)

"Each morning, summarize my open issues and propose reminder comments on issues that haven't
moved in 3+ days":

```
1. items = run("plane mine items --format json")        # read
2. stale = filter items where updated_at is older than 3 days   # LLM/jq
3. summary = LLM turns stale into a human-readable summary        # reasoning
4. show the human the summary + list of proposed comments          # human-in-the-loop
5. only for items the human approved:
     run("plane comment post <NRO-123> 'Reminder: ...'")  # write (after approval)
```

Reads (1) are free; writes (5) only after approval — that boundary is the whole point.

## Real demo

The standup summary script for my work:
[../examples/standup-summary.sh](../examples/standup-summary.sh).
Its `jq` pipeline is a good, compact example of shaping CLI JSON into a human-readable summary.
