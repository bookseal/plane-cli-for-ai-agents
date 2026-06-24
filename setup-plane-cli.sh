#!/usr/bin/env bash
#
# setup-plane-cli.sh
# 자체 호스팅 Plane용 plane-cli-requiem 설치/설정 안내 스크립트.
#
# 사용법:
#   PLANE_INSTANCE_URL="https://plane.bit-habit.com" ./setup-plane-cli.sh
#   (또는 그냥 ./setup-plane-cli.sh 실행 후 프롬프트에 입력)
#
# 이 스크립트는 토큰을 파일에 저장하지 않습니다. 마지막에 직접 실행할
# `plane config` 명령만 안내합니다.

set -euo pipefail

# ── 1. 인스턴스 URL 확보 ───────────────────────────────────────────────
PLANE_INSTANCE_URL="${PLANE_INSTANCE_URL:-}"
if [[ -z "${PLANE_INSTANCE_URL}" ]]; then
  read -r -p "자체 호스팅 Plane 주소를 입력하세요 (예: https://plane.bit-habit.com): " PLANE_INSTANCE_URL
fi

# 끝의 슬래시 제거 (이중 슬래시 방지)
PLANE_INSTANCE_URL="${PLANE_INSTANCE_URL%/}"

if [[ ! "${PLANE_INSTANCE_URL}" =~ ^https?:// ]]; then
  echo "오류: URL은 http:// 또는 https:// 로 시작해야 합니다 → '${PLANE_INSTANCE_URL}'" >&2
  exit 1
fi
echo "→ 사용할 인스턴스: ${PLANE_INSTANCE_URL}"

# ── 2. Rust/cargo 확인 ────────────────────────────────────────────────
if ! command -v cargo >/dev/null 2>&1; then
  echo
  echo "cargo(Rust)가 설치돼 있지 않습니다. 먼저 rustup을 설치하세요:" >&2
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
  echo "  source \"\$HOME/.cargo/env\"" >&2
  echo "설치 후 이 스크립트를 다시 실행하세요." >&2
  exit 1
fi
echo "→ cargo 확인됨: $(cargo --version)"

# ── 3. plane-cli-requiem 설치 ─────────────────────────────────────────
if command -v plane >/dev/null 2>&1; then
  echo "→ 'plane' 명령이 이미 있습니다. 재설치하려면 아래를 직접 실행하세요:"
  echo "    cargo install plane-cli-requiem --force"
else
  echo "→ plane-cli-requiem 설치 중..."
  cargo install plane-cli-requiem
fi

# ── 4. PLANE_API_URL 안내 ─────────────────────────────────────────────
echo
echo "================  다음 단계 (직접 실행)  ================"
echo
echo "1) API 베이스 주소를 환경변수로 설정 (셸마다 필요):"
echo "     export PLANE_API_URL=\"${PLANE_INSTANCE_URL}\""
echo
echo "   매번 자동으로 하려면 ~/.zshrc 에 추가:"
echo "     echo 'export PLANE_API_URL=\"${PLANE_INSTANCE_URL}\"' >> ~/.zshrc && source ~/.zshrc"
echo
echo "2) 워크스페이스 슬러그와 API 토큰으로 설정:"
echo "   (토큰: 웹 UI → Settings → API Tokens. 절대 커밋하지 마세요.)"
echo "     plane config --workspace <slug> --token plane_api_xxx"
echo
echo "3) 연결 확인:"
echo "     plane me"
echo "     plane projects"
echo
echo "========================================================"
