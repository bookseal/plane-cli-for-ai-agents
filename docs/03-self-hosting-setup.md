# 03. Self-hosting setup

Target: `plane-cli-requiem` (Rust, crates.io). How to connect it to the self-hosted instance
`https://plane.bit-habit.com`.

## 0) Install

If you don't have the Rust toolchain, install [rustup](https://rustup.rs) first:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# open a new shell, or:  source "$HOME/.cargo/env"
```

Install the CLI:

```bash
cargo install plane-cli-requiem
```

## 1) The key: change the API base with `PLANE_API_URL`

`plane-cli-requiem` doesn't document this, but the **`PLANE_API_URL`** environment variable lets
you change the API base address. The source reads it in `src/api/plane_api_client.rs` via
`std::env::var("PLANE_API_URL")`. URLs are then assembled by this rule:

```
{PLANE_API_URL}/api/v1/workspaces/{slug}/...
```

So **that one variable makes it work against a self-hosted instance with no source patch.**

```bash
export PLANE_API_URL="https://plane.bit-habit.com"
```

To have it in every shell, add it to `~/.zshrc`:

```bash
echo 'export PLANE_API_URL="https://plane.bit-habit.com"' >> ~/.zshrc
source ~/.zshrc
```

> Note: do not add a trailing slash (`/`). It can produce a double slash like
> `.../v1//workspaces`.

## 2) Find your workspace slug

The slug is the short string that identifies a workspace. How to find it:

- **From the web URL**: after logging in, look at the address bar. The `<slug>` in
  `https://plane.bit-habit.com/<slug>/projects/...` is it.
- **From the workspace settings page**: shown under Workspace Settings → General.

## 3) Issue an API token

Web UI → top-right profile → **Settings → API Tokens → Add API token**.

- Give it a recognizable name (e.g. `macbook-cli`, `agent-readonly`)
- Prefer a **short expiry** (especially for agent tokens)
- The issued `plane_api_...` token is shown **only once**. Store it somewhere safe (a password
  manager).
- ⚠️ **Never commit this token to git.**

## 4) Configure the CLI

```bash
plane config --workspace <slug> --token plane_api_xxx
```

The config is usually saved to something like `~/.config/.../config.toml` (token included).
**Do not commit this file** — this repo's `.gitignore` blocks `config.toml`.

## 5) Check the connection

```bash
plane me          # workspace/auth status → success if it prints
plane projects    # list of projects (each item's identifier is the value for --project)
plane ls --project <IDENTIFIER>   # issues in a specific project
plane mine items  # issues assigned to me
```

> If `plane mine` / `plane ls` errors with "no default project," set a default project once:
> `plane config --project <IDENTIFIER>` (IDENTIFIER is the uppercase identifier from
> `plane projects` output, e.g. `AUTOPLAN`).
>
> Note: this CLI's issue JSON is flat —
> `{ "id": "AUTOPLAN-3", "title": ..., "state": "Backlog", "priority": "None", "due": null }`.
> `state`/`priority` are strings, not objects, so in jq you access `.state`, not `.state.name`.

If `plane me` returns 401/403, check the token/expiry/permissions; if it's a connection error,
check `PLANE_API_URL` and whether the domain is reachable (does it open in a browser?).

---

## Link-patch build

The `plane open` / `plane url` / `plane info` commands build **web links** for a human to look
at, and that part has `app.plane.so` **hard-coded**. On a self-hosted instance the links are
wrong. (Other commands like issue read/create are fine — they only use the API base.)

To fix the links too, get the source, replace the domain, and build locally:

```bash
# 1. get the source
git clone https://github.com/<requiem-repo>/plane-cli-requiem
cd plane-cli-requiem

# 2. replace the hard-coded domain (macOS sed needs -i '')
grep -rl 'app.plane.so' src
sed -i '' 's#app\.plane\.so#plane.bit-habit.com#g' $(grep -rl 'app.plane.so' src)

# 3. install from local source (overrides the crates.io version)
cargo install --path .
```

> This is **optional**. If you don't use the link-building commands, `PLANE_API_URL` alone is
> enough.

Next: exposing this CLI as a tool for an AI agent →
[04-ai-agent-integration.md](04-ai-agent-integration.md).
