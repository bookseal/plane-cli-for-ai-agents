#!/usr/bin/env bash
#
# setup-plane-cli.sh
# Install/config helper for plane-cli-requiem against self-hosted Plane.
#
# Usage:
#   PLANE_INSTANCE_URL="https://plane.bit-habit.com" ./setup-plane-cli.sh
#   (or just run ./setup-plane-cli.sh and enter it at the prompt)
#
# This script does not store a token in any file. At the end it only shows you
# the `plane config` command to run yourself.

set -euo pipefail

# ── 1. Get the instance URL ───────────────────────────────────────────
PLANE_INSTANCE_URL="${PLANE_INSTANCE_URL:-}"
if [[ -z "${PLANE_INSTANCE_URL}" ]]; then
  read -r -p "Enter your self-hosted Plane address (e.g. https://plane.bit-habit.com): " PLANE_INSTANCE_URL
fi

# Strip trailing slash (avoid double slashes)
PLANE_INSTANCE_URL="${PLANE_INSTANCE_URL%/}"

if [[ ! "${PLANE_INSTANCE_URL}" =~ ^https?:// ]]; then
  echo "Error: URL must start with http:// or https:// → '${PLANE_INSTANCE_URL}'" >&2
  exit 1
fi
echo "→ Using instance: ${PLANE_INSTANCE_URL}"

# ── 2. Check Rust/cargo ───────────────────────────────────────────────
if ! command -v cargo >/dev/null 2>&1; then
  echo
  echo "cargo (Rust) is not installed. Install rustup first:" >&2
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
  echo "  source \"\$HOME/.cargo/env\"" >&2
  echo "Then run this script again." >&2
  exit 1
fi
echo "→ cargo found: $(cargo --version)"

# ── 3. Install plane-cli-requiem ──────────────────────────────────────
if command -v plane >/dev/null 2>&1; then
  echo "→ 'plane' command already exists. To reinstall, run this yourself:"
  echo "    cargo install plane-cli-requiem --force"
else
  echo "→ Installing plane-cli-requiem..."
  cargo install plane-cli-requiem
fi

# ── 4. PLANE_API_URL guidance ─────────────────────────────────────────
echo
echo "================  Next steps (run yourself)  ================"
echo
echo "1) Set the API base address as an env var (needed per shell):"
echo "     export PLANE_API_URL=\"${PLANE_INSTANCE_URL}\""
echo
echo "   To do it automatically every time, add it to ~/.zshrc:"
echo "     echo 'export PLANE_API_URL=\"${PLANE_INSTANCE_URL}\"' >> ~/.zshrc && source ~/.zshrc"
echo
echo "2) Configure with your workspace slug and API token:"
echo "   (token: web UI → Settings → API Tokens. Never commit it.)"
echo "     plane config --workspace <slug> --token plane_api_xxx"
echo
echo "3) Check the connection:"
echo "     plane me"
echo "     plane projects"
echo
echo "============================================================"
