# 02. Why a CLI, why an AI agent

## Why a CLI

Reasons to put a CLI layer in front instead of handing the web API straight to the agent:

### 1) Text in / text out — deterministic parsing

`plane-cli-requiem` supports `--format json` (and `csv`). The agent doesn't scrape HTML or guess
at a screen — it **parses structured output directly**.

```bash
plane mine items --format json
# → [{ "id": "...", "name": "...", "state": "In Progress", ... }, ...]
```

### 2) Composability — pipe small commands together

This is the Unix philosophy. CLI output can be shaped with `jq`, `grep`, `sort`, so a big task
becomes a composition of small commands.

```bash
plane mine items --format json | jq '[.[] | select(.state != "Done")] | length'
# → count of my open issues
```

### 3) Determinism — same input, same behavior

For a CLI, the arguments *are* the behavior. The same command does the same thing. It isn't
shaken by UI layout changes or screen inference, so agent behavior is **easy to reproduce and
test**.

### 4) Exit codes — program success/failure

A command returns `0` on success and non-zero on failure. That lets you design retries, aborts,
and branching cleanly in an agent loop.

```bash
if plane create "Refactor the payments module" --project X ; then
  echo "created"
else
  echo "failed — check token/permissions" >&2
fi
```

### 5) Scriptable + guardrails — easy to scope permissions

Through a CLI you can enforce, in one place, an **allowed-command whitelist** like "this agent
may only use `plane issue list` and `plane mine`." Hand over raw REST and you have to redraw that
boundary every time. (Guardrails: [doc 04](04-ai-agent-integration.md#guardrails).)

## Why an AI agent

Once the CLI is ready, putting an agent on top of it is the natural next step.

- **Delegate repetitive, structured work**: daily standup summaries, triaging stale issues,
  tidying labels.
- **Natural language → structured action**: turning unstructured text into structured CLI
  commands — "pull the action items from these meeting notes and make them issues" — is something
  an LLM does well.
- **Holds context**: the agent remembers results across several commands and performs multi-step
  work ("list open issues → judge priority → comment to the assignee").
- **Humans focus on review**: the agent drafts (creates issues, proposes state changes) and the
  human only approves or edits — **write operations are safest behind a human check.**

## The core analogy

> Handing over the REST API is giving the agent a **box of parts**.
> Handing over the CLI is giving it **power tools**.
> You can build with parts, but tools make it faster, safer, and reproducible.

Next: the actual steps to connect the CLI to a self-hosted instance →
[03-self-hosting-setup.md](03-self-hosting-setup.md).
