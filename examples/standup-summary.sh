#!/usr/bin/env bash
#
# standup-summary.sh
# Demo: fetch the issues assigned to me and print a "standup summary."
#   plane mine items --format json | jq <filter/format>
#
# Assumes:
#   - plane-cli-requiem is installed and `plane config` is done
#   - PLANE_API_URL points at your self-hosted address
#   - jq is installed  (brew install jq)
#
# Usage:
#   ./standup-summary.sh

set -euo pipefail

# ── Pre-checks ────────────────────────────────────────────────────────
command -v plane >/dev/null 2>&1 || { echo "Error: 'plane' command not found. See README." >&2; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "Error: 'jq' not found. Run 'brew install jq' and retry." >&2; exit 1; }

if [[ -z "${PLANE_API_URL:-}" ]]; then
  echo "Warning: PLANE_API_URL is empty. If self-hosted, export it." >&2
fi

# ── 1. Fetch my issues as JSON ────────────────────────────────────────
# Take --format json so jq can parse deterministically.
echo "→ Fetching my issues..." >&2
items_json="$(plane mine items --format json)"

# Guard against empty results
count="$(printf '%s' "${items_json}" | jq 'length')"
if [[ "${count}" -eq 0 ]]; then
  echo "No issues assigned to you. 🎉"
  exit 0
fi

# ── 2. Shape into a standup summary ───────────────────────────────────
echo "📋 Today's standup ($(date '+%Y-%m-%d'))"
echo "────────────────────────────────────────"

# Issue array → one human-readable line per issue.
#   - exclude Done/Cancelled issues from standup (select)
#   - sort by state for readability (sort_by)
#   - fall back to a default for missing fields (// "-")
#   target output, e.g.:  • AUTOPLAN-3  [Backlog] Crawl the guide site  (priority: None)
#
# Field shape (confirmed on plane-cli-requiem v0.3.3, self-hosted kiba instance):
#   { "id": "AUTOPLAN-3", "title": ..., "state": "Backlog", "priority": "None", "due": null }
#   state/priority are plain strings, not objects.
JQ_FILTER='
  map(select((.state // "") | test("Done|Cancelled") | not))
  | sort_by(.state // "")
  | .[]
  | "  • \(.id)  [\(.state // "-")] \(.title)  (priority: \(.priority // "-"))"
'

printf '%s' "${items_json}" | jq -r "${JQ_FILTER}"

echo "────────────────────────────────────────"
echo "${count} total"
