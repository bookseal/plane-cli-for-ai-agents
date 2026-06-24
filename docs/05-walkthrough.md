# 05. Real-world walkthrough — from install to first write (field notes)

This doc records, as-is, the steps and traps from actually connecting `plane-cli-requiem`
**v0.3.3** to the self-hosted instance (`https://plane.bit-habit.com`, workspace `kiba`).
Where the other docs say "here's how it should work," this one says "here's how it actually
went."

## 0. The result at a glance

- Connected to self-hosted Plane from a MacBook over the internet, via the CLI
- Claude Code (the AI agent) directly **read** issues (`plane ls`/`show`) and **wrote** them
  (`plane create`)
- Along the way, cross-checked the **CLI's false signals / config traps / real JSON schema**
  against the raw API

## 1. Install

```bash
# if you don't have Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

cargo install plane-cli-requiem      # → ~/.cargo/bin/plane (v0.3.3)
```

> ⚠️ **PATH trap**: in non-login-shell environments (scripts, some automation), `~/.cargo/bin`
> isn't on PATH, so you can get `plane: command not found`. To be safe, use the full path
> `~/.cargo/bin/plane`, or put `~/.cargo/bin` on PATH.

## 2. Set the API base

```bash
echo 'export PLANE_API_URL="https://plane.bit-habit.com"' >> ~/.zshrc
source ~/.zshrc
```

That one variable connects to self-hosted with no patch. (Reasoning: [03](03-self-hosting-setup.md))

## 3. Auth — where I struggled the most

### Trap A: passing `--token` alone doesn't change the workspace token

```bash
# ❌ this leaves the old (revoked) token in place
plane config --token plane_api_NEW

# ✅ you must pass --workspace too for it to overwrite
plane config --workspace kiba --token plane_api_NEW
```

Watch out especially when refreshing after rotating a token. If you put in a new token and keep
getting 403, this is almost always the cause.

### Trap B: `plane me`'s "authenticated" is not token validity

```bash
plane me
# Auth: authenticated (workspace-scoped)   ← this only means "local config exists"
```

`me` answers from the local `config.toml` only. **It does not verify the token is actually valid
on the server.** So you can have `me` pass while `create`/`ls` return 403.

### Diagnosis: cross-check with the raw API

When the CLI gives a false signal, poke the REST layer one level down to find the truth:

```bash
curl -sS -H "X-API-Key: plane_api_XXXX" \
  "https://plane.bit-habit.com/api/v1/workspaces/kiba/projects/" \
  -w "\n[http %{http_code}]\n"
# 200 → the token itself is valid (the problem is CLI config)
# 403 {"detail":"Given API token is not valid"} → the token is revoked/typo'd
```

Config file location and shape (never commit the token):

```toml
# ~/.plane-cli-requiem/config.toml
active_workspace = "kiba"

[workspaces.kiba]
api_key = "plane_api_..."
default_project = "autoplan"
```

### The token is once-only — you don't enter it every time

The token is **stored permanently** in the file above and reused regardless of shell/reboot. You
only re-enter it when: the token is revoked/rotated, it expires, you add a new workspace, or you
use a new machine. This "store the long-lived credential once → reuse unattended" model is
exactly the foundation that lets **an AI agent run with no human in the loop.**

## 4. Read — the real JSON schema

```bash
plane projects                       # list of projects (identifier is the --project value)
plane ls --project AUTOPLAN --format json
```

> ⚠️ **Schema trap**: contrary to docs/intuition, this CLI's issue JSON is **flat**.
> `state`/`priority` are **strings**, not objects.

```json
{ "id": "AUTOPLAN-3", "title": "...", "state": "Backlog", "priority": "None", "due": null }
```

So jq uses `.state`, not `.state.name`, and the title is `.title`, not `.name`:

```bash
plane ls --project AUTOPLAN --format json \
  | jq -r 'sort_by(.id) | .[] | "  \(.id)  [\(.state)] \(.title)"'
```

> Another trap: `plane mine` errors with "no default project" if there's no default. Set it once
> with `plane config --project AUTOPLAN`.

## 5. Write — the agent actually creates an issue

```bash
plane create "Test" --project AUTOPLAN
# → Created AUTOPLAN-9: Test

plane show AUTOPLAN-9
#   State: Backlog  / Priority: —  / Assignees: 0
```

This is the key demo: **not a human clicking, but the agent creating an issue by command**, then
verifying with `plane show`. (To clean up, remove it with `plane delete AUTOPLAN-9 --yes`.)

## 6. Self-hosting limitations found

- `plane open` / `url` / `info`: `app.plane.so` is hard-coded in the web link → wrong links on
  self-hosted. (Other commands are fine.) To fix, replace in source and build —
  [03](03-self-hosting-setup.md#link-patch-build)
- `plane show`'s **Relations** shows `unavailable (internal API may not support API key auth)` —
  some internal APIs may not support API-key auth. If you need the relations graph, account for
  this constraint.

## 7. Lessons learned (from the agent-tooling angle)

1. **Distrust an abstraction's false signals.** Like `me`'s "authenticated," convenience commands
   may only see local state. At decisive moments, confirm ground truth with the raw API.
2. **Don't guess the schema — sample it once and lock it in.** Use `... --format json | jq '.[0]'`
   to see real field names and fit your parser (here `.title`, and `.state` as a string).
3. **Credentials are stored once and reused unattended** — which makes that file the key itself:
   least privilege, short expiry, no plaintext exposure.
4. **Reads are free; writes go with verification.** A `create` then `show` loop is the safe one.
