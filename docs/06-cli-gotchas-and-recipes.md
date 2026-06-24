# 06 · CLI gotchas & recipes (agent field notes)

Verified by actually working with `plane-cli-requiem` v0.3.3 against self-hosted Plane
(`https://plane.bit-habit.com`, workspace `kiba`). **Read this first if you're another AI agent
about to work with this CLI** — you won't get stuck in the same places. Every item here is one I
hit, root-caused, and resolved.

> One-line summary: the CLI is great for **reads / issue CRUD / module & cycle assignment**, but
> **cycle creation, project feature toggles, and date edits** are missing or buggy and must be
> **worked around with the raw REST API.**

---

## 0. 30-second setup (what the agent should check every time)

```bash
# (1) base URL is env-only. Without it, the CLI hits the cloud (api.plane.so) and 404s self-hosted.
export PLANE_API_URL="https://plane.bit-habit.com"

# (2) full path to the binary (non-login/non-interactive shells don't have cargo bin on PATH)
PCR=~/.cargo/bin/plane-cli-requiem

# (3) confirm auth / target
"$PCR" me            # workspace/project/auth status
"$PCR" projects      # list of project slugs
"$PCR" config --project AUTOPLAN   # pin a default project (recommended)
```

**Key trap ①** — `PLANE_API_URL` takes the base URL **only as an environment variable**
(`src/api/plane_api_client.rs`: defaults to `https://api.plane.so` if unset). There's no slot for
it in config.toml. A human terminal can `export` it in `~/.zshenv` so it's automatic, but in
**shells that don't read rc files (many agent sandboxes, cron, `zsh -f`), pass it inline on every
command**:

```bash
PLANE_API_URL="https://plane.bit-habit.com" ~/.cargo/bin/plane-cli-requiem ls
```

---

## 1. Auth / target

- The token is stored in `[workspaces.<slug>].api_key` in `~/.plane-cli-requiem/config.toml`. If
  the `PLANE_API_KEY` env var is set, it **takes precedence**.
- `plane me`'s `authenticated` is **only a local signal, not token validation.** Real
  confirmation comes from an actual read command (`projects`, `ls`) or a raw-API cross-check.
- Re-registering a token must include `--workspace`:
  `plane config --workspace kiba --token <NEW>` (`--token` alone doesn't change anything).
- Many subcommands need a **default project**. If none is set, you get
  `Error: no default project configured` → use `config --project <slug>` or pass `--project` on
  each command.

---

## 2. Domain model: 5 axes, all orthogonal

| Axis | Values | Command to set |
|------|--------|----------------|
| **Priority** | `urgent` / `high` / `medium` / `low` / `none` | `update --priority` |
| **State** (workflow) | `Backlog` / `Todo` / `In Progress` / `Done` / `Cancelled` | `update --state` (name, case-insensitive) |
| **Module** (persistent category) | created per project | `update --module` / `modules add` |
| **Cycle** (time-boxed sprint) | created per project | `mv --cycle` / `cycles add` |
| **Label** | created per project | `label add` / `update --label` |

→ Example: "Sprint 3 but state Backlog" is not a contradiction — **cycle and state are separate
axes**, so it's normal. Set one item's priority/state/module/cycle in one go:

```bash
"$PCR" update AUTOPLAN-1 --priority high --state "In Progress" --module "Staffing/Qualification System (Quali-fit Core)"
"$PCR" mv     AUTOPLAN-1 --cycle "Sprint 1"
```

Don't guess the **exact name** of a State/Priority — always look it up first:
`plane states --project <slug> --format json`.

---

## 3. Traps I hit (verified)

### 3-1. `cycles create` always 400 — and the error message lies
```
$ plane cycles create "Sprint 1" --start ... --end ...
Error: Plane API returned 400 Bad Request: {"non_field_errors":["Project ID is required"]}
```
- Happens because the CLI **doesn't put project in the request body**. Same even with `--project`
  (it doesn't go into the body).
- And `"Project ID is required"` is just the **surface message**. Put project in the body via the
  raw API and the real cause shows up:
  `{"non_field_errors":["Cycles are not enabled for this project"]}`.
- So the root cause was that **Cycles was disabled for the project.** (Modules was on, so the CLI
  worked for it.)

**Fix** — ① turn on the feature toggle, ② create the cycle via raw API:
```bash
BASE=https://plane.bit-habit.com; SLUG=kiba; PID=<project-uuid>
KEY=$(grep '^api_key' ~/.plane-cli-requiem/config.toml | sed -E 's/.*"([^"]+)".*/\1/')

# ① turn on Cycles (project feature toggle)
curl -sS -X PATCH "$BASE/api/v1/workspaces/$SLUG/projects/$PID/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"cycle_view": true}'        # same for module_view / page_view / intake_view, etc.

# ② create the cycle (project_id is required in the body!)
curl -sS -X POST "$BASE/api/v1/workspaces/$SLUG/projects/$PID/cycles/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"name":"Sprint 1","start_date":"2026-06-23","end_date":"2026-08-31","project_id":"'$PID'"}'
```
After creation, **assign/list/delete with the CLI again**: `mv --cycle`, `cycles ls "Sprint 1"`,
`cycles add`.

### 3-2. Cycle **date edits** aren't in the CLI → raw PATCH
`cycles` has only `create/delete/add/remove`, no update. To change dates:
```bash
curl -sS -X PATCH "$BASE/api/v1/workspaces/$SLUG/projects/$PID/cycles/<cycle-uuid>/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"start_date":"2026-06-23","end_date":"2026-08-31","project_id":"'$PID'"}'
```
The cycle-uuid is the `id` from `plane cycles ls --format json`.

### 3-3. Transient failures right after rapid writes (rate-limit)
Run 5+ `update`/`mv` writes back-to-back quickly and some may fail silently. **Retrying them
individually succeeds.** Design batch loops to verify results and re-run only the failures.

### 3-4. Missing `tomllib` (system python < 3.11)
`import tomllib` can break when parsing the config.toml token. Do it safely:
```bash
KEY=$(grep -E '^api_key' ~/.plane-cli-requiem/config.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
```

### 3-5. Output that looks broken is usually just an encoding display
If git shows non-ASCII paths as octal escapes, use `git -c core.quotepath=false ...`. Take CLI
output as `--format json` and parse with `python3`/`jq` for determinism.

---

## 4. Recipes I use often

```bash
# all issues (untruncated) — take json to bypass the display limit
"$PCR" ls --project AUTOPLAN --format json | python3 -c '
import sys,json
for w in sorted(json.load(sys.stdin),key=lambda x:x["id"]):
    print(f"{w[\"id\"]:<12}{w[\"priority\"]:<7}{w[\"state\"]}")'

# verify module/cycle membership (list items by name)
"$PCR" modules ls "Staffing/Qualification System (Quali-fit Core)" --format json
"$PCR" cycles  ls "Sprint 1" --format json

# change several items at once
"$PCR" bulk AUTOPLAN-7 AUTOPLAN-8 --priority low --state Backlog

# detail (AC/comments/activity), create, comment
"$PCR" show AUTOPLAN-1
"$PCR" create "New task" --priority high --state Todo
"$PCR" comment AUTOPLAN-1 post "Progress update"
```

If you need a **dry-run preview** before writing, `update`/`bulk` have a `--dry-run` flag.

---

## 5. Raw-API escape hatch summary

Endpoints to use when the CLI can't do something or is buggy (all with the `X-API-Key` header):

| Task | Method · Path | Notes |
|------|---------------|-------|
| Project feature toggle | `PATCH /workspaces/{slug}/projects/{pid}/` | `{"cycle_view":true}`, etc. |
| Create a cycle | `POST /workspaces/{slug}/projects/{pid}/cycles/` | `project_id` required in body |
| Edit cycle dates | `PATCH .../cycles/{cid}/` | include `project_id` in the body |
| Cross-check token validity | `GET /workspaces/{slug}/projects/` | 200 means valid |

> The official API schema is in the crate's `docs/plane-api-reference.md`, but **this self-hosted
> server version may differ in field requirements** (e.g. cycle creation requires `project_id` in
> the body). When stuck, print the raw response body to see the real error — don't trust the
> surface message.

---

## 6. Quick reference (this instance)

- workspace slug: `kiba`
- projects: `AUTOPLAN` (work-automation planning, real data), `KIBA` (Plane demo)
- base URL: `https://plane.bit-habit.com` (env `PLANE_API_URL`)
- token: `~/.plane-cli-requiem/config.toml` — **never commit/print**, rotate if exposed
