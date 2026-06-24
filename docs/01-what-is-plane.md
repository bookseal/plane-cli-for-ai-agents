# 01. What is Plane

## One-sentence summary

**Plane** is an open-source alternative to Jira/Linear — a project management tool that handles
issue tracking, sprints (cycles), roadmaps, and docs in one place. It can be **self-hosted**, so
your data stays on your own server (this repo uses `https://plane.bit-habit.com`, an Ubuntu + k3s
instance).

## Data model

To understand the CLI and API, you need the object hierarchy. The URLs follow it directly:

```
Workspace (org-level unit — identified by a slug)
└── Project
    ├── Issue (the basic unit of work)
    │   ├── State        (Backlog / Todo / In Progress / Done / Cancelled)
    │   ├── Assignee
    │   ├── Label
    │   ├── Comment
    │   └── Relation     (blocks / blocked_by / duplicate / relates_to)
    ├── Cycle  (a time-boxed sprint — groups issues)
    └── Module (groups issues by feature/topic)
```

Key points:

- **A workspace is identified by its `slug`.** Example: the `my-team` in
  `https://plane.bit-habit.com/my-team/...`. That slug is exactly the value you pass to
  `plane config --workspace <slug>`.
- **The issue is the center.** Most agent work is expressed as creating, reading, changing the
  state of, or commenting on issues.
- **Cycle vs Module**: a Cycle groups by *time* (this week's sprint); a Module groups by *topic*
  (the payments feature). One issue can belong to both at once.

## API URLs follow the hierarchy exactly

The REST paths `plane-cli-requiem` calls are assembled like this:

```
{PLANE_API_URL}/api/v1/workspaces/{slug}/projects/{project_id}/issues/...
```

So changing just `PLANE_API_URL` to your self-hosted domain completes every other path by the
rules. That's the core idea of [03-self-hosting-setup.md](03-self-hosting-setup.md).

## Why drive this with a CLI / agent

The web UI is great for a human clicking one thing at a time, but:

- It's inefficient for **repetitive work** like "every morning, summarize my open issues in the
  current cycle."
- It's tedious for **bulk work** like "create 10 action items from meeting notes as issues."
- Above all, **an AI agent can't click** — it needs a text interface.

→ The next doc covers "why a CLI and why an agent":
[02-why-cli-for-ai-agents.md](02-why-cli-for-ai-agents.md).
