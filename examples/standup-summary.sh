#!/usr/bin/env bash
#
# standup-summary.sh
# 데모: 내게 할당된 이슈를 가져와 "스탠드업 요약"으로 출력한다.
#   plane mine items --format json | jq <필터/포맷>
#
# 전제:
#   - plane-cli-requiem 설치됨, `plane config` 완료
#   - PLANE_API_URL 이 자체 호스팅 주소로 설정됨
#   - jq 설치됨  (brew install jq)
#
# 사용법:
#   ./standup-summary.sh

set -euo pipefail

# ── 사전 점검 ─────────────────────────────────────────────────────────
command -v plane >/dev/null 2>&1 || { echo "오류: 'plane' 명령이 없습니다. README 참고." >&2; exit 1; }
command -v jq    >/dev/null 2>&1 || { echo "오류: 'jq'가 없습니다. 'brew install jq' 후 다시." >&2; exit 1; }

if [[ -z "${PLANE_API_URL:-}" ]]; then
  echo "경고: PLANE_API_URL 이 비어 있습니다. 자체 호스팅이면 export 하세요." >&2
fi

# ── 1. 내 이슈를 JSON으로 가져오기 ────────────────────────────────────
# --format json 으로 받아야 jq로 결정론적 파싱이 가능하다.
echo "→ 내 이슈를 가져오는 중..." >&2
items_json="$(plane mine items --format json)"

# 빈 결과 방어
count="$(printf '%s' "${items_json}" | jq 'length')"
if [[ "${count}" -eq 0 ]]; then
  echo "할당된 이슈가 없습니다. 🎉"
  exit 0
fi

# ── 2. 스탠드업 요약으로 가공 ─────────────────────────────────────────
echo "📋 오늘의 스탠드업 ($(date '+%Y-%m-%d'))"
echo "────────────────────────────────────────"

# 이슈 배열 → 사람이 읽기 좋은 한 줄/이슈로 가공.
#   - 완료/취소된 이슈는 스탠드업에서 제외 (select)
#   - 상태별로 묶어 보기 좋게 정렬 (sort_by)
#   - 누락 필드는 기본값으로 대체 (// "-")
#   목표 출력 예:  • [In Progress] 결제 모듈 리팩터링  (priority: high)
#
# 참고: 자체 호스팅 인스턴스의 실제 필드명이 다르면 아래를 한 번 확인하고 맞추세요.
#   plane mine items --format json | jq '.[0]'
JQ_FILTER='
  map(select((.state // "") | test("Done|Cancelled") | not))
  | sort_by(.state // "")
  | .[]
  | "  • [\(.state // "-")] \(.name)  (priority: \(.priority // "-"))"
'

printf '%s' "${items_json}" | jq -r "${JQ_FILTER}"

echo "────────────────────────────────────────"
echo "총 ${count}건"
