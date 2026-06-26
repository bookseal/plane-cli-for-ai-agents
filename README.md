> ⚠️ **Archived (June 2026).** This project explored driving self-hosted Plane from a CLI / AI agent.
> After putting it head-to-head with **GitHub Projects** (`gh` CLI + Projects v2) on our real
> meeting-notes → task reconcile workflow, we concluded GitHub Projects fit better for us
> (zero hosting, work + code + issues in one place) and **migrated off Plane**. Kept public and
> read-only as a record of the exploration and the decision. The live setup & writeup now live in
> [`KIBA-Automation/project_management_with_ai_agent`](https://github.com/KIBA-Automation/project_management_with_ai_agent).

# plane-cli-for-ai-agents

A repo documenting how to **drive self-hosted [Plane](https://plane.so)** (the open-source
project management tool) **from a CLI**, and then how to **let an AI agent read and write
Plane as a first-class citizen.**

- Target instance: self-hosted Plane (`https://plane.bit-habit.com`, Ubuntu + k3s)
- Client: a MacBook (the domain is public, so it connects over the internet — no SSH needed)
- End goal: expose the same CLI a human uses as a tool for an AI agent, so the agent can
  create issues, post comments, and tidy up cycles.

---

## Why this repo

Plane has a great web UI, but **an AI agent works with text, not clicks.**
Handing an agent the raw REST API means re-teaching it auth, paging, error handling, and URL
assembly every time — and it's hard to scope its permissions. Instead, **wrap a good CLI as a
tool** and you get:

- Text in / text out (especially `--format json`) → the agent parses deterministically
- Exit codes for success/failure → easy to design loops and retries
- Shell pipes (`| jq`, `| grep`) → compose small commands into bigger tasks
- A single place for guardrails (an allowed-command whitelist, least-privilege tokens)

Full reasoning: [docs/02-why-cli-for-ai-agents.md](docs/02-why-cli-for-ai-agents.md).

---

## Which CLI (avoid the confusion)

Several things are called a "Plane CLI." Here's how they sort out:

| Name | Purpose | Right for us? |
|------|---------|---------------|
| Official **Prime CLI** | Server admin (`install`/`start`/`stop`). No login concept. | ❌ Ops only, no data ops |
| **`plane-cli-requiem`** (Rust, crates.io) | Issue CRUD, `mine`, cycles/modules, comments, relations, dashboard. **JSON/CSV output** | ✅ Recommended |
| Official **Plane MCP Server** | An MCP tool server for agents | 🟡 Alternative / complement |

This repo is built around **`plane-cli-requiem`**.

---

## Quick start (self-hosted)

> Key fact: `plane-cli-requiem` is undocumented on this point, but the **`PLANE_API_URL`**
> environment variable lets you change the API base address. That one variable connects it to a
> self-hosted instance with no source patching.

```bash
cargo install plane-cli-requiem
export PLANE_API_URL="https://plane.bit-habit.com"
plane config --workspace <slug> --token plane_api_xxx
```

Check the connection:

```bash
plane me          # success if your user info prints as JSON
plane projects    # list of projects
```

To do it all in one go with the helper script:

```bash
./setup-plane-cli.sh    # prompts for PLANE_INSTANCE_URL, then guides install/config
```

Full setup (finding the slug, the link-patch build) is in
[docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md).

---

## Known limitation (self-hosted)

`plane open` / `plane url` / `plane info` have `app.plane.so` **hard-coded**, so on a
self-hosted instance they produce wrong web links. (Every other command is fine — they only
use the API base.) To fix the links too, replace `app.plane.so` with your domain in the crate
source and build locally with `cargo install --path .`. Steps are in
[docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md#link-patch-build).

---

## The whole journey

1. **Understand** — what Plane is and what its data model looks like
   → [docs/01-what-is-plane.md](docs/01-what-is-plane.md)
2. **Why a CLI / why an agent**
   → [docs/02-why-cli-for-ai-agents.md](docs/02-why-cli-for-ai-agents.md)
3. **Self-hosting setup** — `PLANE_API_URL`, the slug, the link patch
   → [docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md)
4. **AI agent integration** — exposing the CLI as a tool, MCP, guardrails, an example loop
   → [docs/04-ai-agent-integration.md](docs/04-ai-agent-integration.md)
5. **Demo** — a standup summary of my work
   → [examples/standup-summary.sh](examples/standup-summary.sh)
6. **Real-world walkthrough** — from install to first write, with the traps I actually hit
   → [docs/05-walkthrough.md](docs/05-walkthrough.md)
7. **CLI gotchas & recipes** — where agents get stuck (the cycle-creation bug, feature toggles,
   raw-API workarounds) and the commands that actually work
   → [docs/06-cli-gotchas-and-recipes.md](docs/06-cli-gotchas-and-recipes.md)
8. **Claude Code's Plane MCP** — using the official Plane MCP server from Claude Code
   → [docs/07-claude-code-plane-mcp.md](docs/07-claude-code-plane-mcp.md)

---

## Security (please read)

- **Never commit an API token.** `.gitignore` blocks `.env`, `config.toml`, and `*.token`, but
  the final responsibility is yours. Run `git grep -i plane_api_` before committing.
- For agent tokens, use **least privilege + short expiry**. Start read-mostly where you can, and
  keep write access in a separate token.
- Full guardrails: [docs/04-ai-agent-integration.md](docs/04-ai-agent-integration.md#guardrails).

---

## License

[MIT](LICENSE)
