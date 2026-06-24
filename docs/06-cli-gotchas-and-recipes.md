# 06 · CLI 함정과 레시피 (에이전트 실전 노트)

`plane-cli-requiem` v0.3.3을 자체 호스팅 Plane(`https://plane.bit-habit.com`, workspace `kiba`)에
붙여 실제로 작업하며 검증한 내용입니다. **다른 AI 에이전트가 이 CLI로 일할 때 먼저 읽으면**
같은 곳에서 막히지 않습니다. 모든 항목은 "겪고 → 원인 파악 → 해결"까지 확인된 것만 적습니다.

> 한 줄 요약: CLI는 **읽기/이슈 CRUD/모듈·사이클 배정**엔 훌륭하지만, **사이클 생성·프로젝트
> 기능 토글·날짜 수정**은 못 하거나 버그가 있어 **raw REST API로 우회**해야 합니다.

---

## 0. 30초 셋업 (에이전트가 매번 확인할 것)

```bash
# (1) base URL은 env-only. 안 주면 클라우드(api.plane.so)로 붙어 self-hosted를 404냄.
export PLANE_API_URL="https://plane.bit-habit.com"

# (2) 바이너리 풀경로 (비로그인/비인터랙티브 셸은 PATH에 cargo bin 없음)
PCR=~/.cargo/bin/plane-cli-requiem

# (3) 인증·타깃 확인
"$PCR" me            # workspace/project/auth 상태
"$PCR" projects      # 프로젝트 슬러그 목록
"$PCR" config --project AUTOPLAN   # 기본 프로젝트 고정(권장)
```

**핵심 함정 ①** — `PLANE_API_URL`은 **환경변수로만** base URL을 받습니다
(`src/api/plane_api_client.rs`: 없으면 기본 `https://api.plane.so`). config.toml에는 슬롯이 없어요.
사람 터미널은 `~/.zshenv`에 export해두면 자동이지만, **rc를 안 읽는 셸(많은 에이전트 샌드박스,
cron, `zsh -f`)에서는 명령마다 인라인으로** 실어야 합니다:

```bash
PLANE_API_URL="https://plane.bit-habit.com" ~/.cargo/bin/plane-cli-requiem ls
```

---

## 1. 인증 / 타깃

- 토큰은 `~/.plane-cli-requiem/config.toml`의 `[workspaces.<slug>].api_key`에 저장됩니다.
  `PLANE_API_KEY` 환경변수가 있으면 그게 **우선**합니다.
- `plane me`의 `authenticated`는 **로컬 신호일 뿐 토큰 유효성 검증이 아닙니다.** 진짜 확인은
  실제 읽기 명령(`projects`, `ls`)이나 raw API 교차검증으로 하세요.
- 토큰 재등록은 반드시 `--workspace`와 함께: `plane config --workspace kiba --token <NEW>`
  (`--token`만 단독으로 주면 안 바뀜).
- 많은 서브커맨드는 **기본 프로젝트**가 필요합니다. 안 잡혀 있으면
  `Error: no default project configured` → `config --project <slug>` 또는 각 명령에 `--project`.

---

## 2. 도메인 모델: 5개 축은 서로 직교

| 축 | 값 | 설정 명령 |
|----|-----|-----------|
| **Priority** | `urgent` / `high` / `medium` / `low` / `none` | `update --priority` |
| **State** (워크플로) | `Backlog` / `Todo` / `In Progress` / `Done` / `Cancelled` | `update --state` (이름, 대소문자 무시) |
| **Module** (영속 카테고리) | 프로젝트별 생성 | `update --module` / `modules add` |
| **Cycle** (시간박스 스프린트) | 프로젝트별 생성 | `mv --cycle` / `cycles add` |
| **Label** | 프로젝트별 생성 | `label add` / `update --label` |

→ 예: "Sprint 3인데 상태는 Backlog"는 모순이 아니라 **사이클·상태가 별개 축**이라 정상입니다.
한 항목의 우선순위/상태/모듈/사이클을 한 번에:

```bash
"$PCR" update AUTOPLAN-1 --priority high --state "In Progress" --module "인력/자격 시스템 (Quali-fit Core)"
"$PCR" mv     AUTOPLAN-1 --cycle "Sprint 1"
```

State/Priority의 **정확한 이름**은 추측하지 말고 항상 먼저 조회:
`plane states --project <slug> --format json`.

---

## 3. 겪은 함정 (검증됨)

### 3-1. `cycles create`가 항상 400 — 그리고 에러 메시지가 거짓말
```
$ plane cycles create "Sprint 1" --start ... --end ...
Error: Plane API returned 400 Bad Request: {"non_field_errors":["Project ID is required"]}
```
- CLI가 요청 **본문에 project를 안 실어** 발생. `--project`를 줘도 동일(본문엔 안 들어감).
- 게다가 `"Project ID is required"`는 **표면 메시지**입니다. raw API로 project를 본문에 넣어보면
  진짜 원인이 드러납니다: `{"non_field_errors":["Cycles are not enabled for this project"]}`.
- 즉 **프로젝트에서 Cycles 기능이 꺼져 있던 것**이 근본 원인. (Modules는 켜져 있어 CLI로 잘 됨.)

**해결** — ① 기능 토글을 켜고 ② raw API로 사이클 생성:
```bash
BASE=https://plane.bit-habit.com; SLUG=kiba; PID=<project-uuid>
KEY=$(grep '^api_key' ~/.plane-cli-requiem/config.toml | sed -E 's/.*"([^"]+)".*/\1/')

# ① Cycles 기능 켜기 (프로젝트 기능 토글)
curl -sS -X PATCH "$BASE/api/v1/workspaces/$SLUG/projects/$PID/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"cycle_view": true}'        # module_view / page_view / intake_view 등도 동일

# ② 사이클 생성 (본문에 project_id 필수!)
curl -sS -X POST "$BASE/api/v1/workspaces/$SLUG/projects/$PID/cycles/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"name":"Sprint 1","start_date":"2026-06-23","end_date":"2026-08-31","project_id":"'$PID'"}'
```
생성 후 **배정·조회·삭제는 다시 CLI로** 가능: `mv --cycle`, `cycles ls "Sprint 1"`, `cycles add`.

### 3-2. 사이클 **날짜 수정**은 CLI에 없음 → raw PATCH
`cycles`엔 `create/delete/add/remove`만 있고 update가 없습니다. 날짜 변경은:
```bash
curl -sS -X PATCH "$BASE/api/v1/workspaces/$SLUG/projects/$PID/cycles/<cycle-uuid>/" \
  -H "X-API-Key: $KEY" -H 'Content-Type: application/json' \
  -d '{"start_date":"2026-06-23","end_date":"2026-08-31","project_id":"'$PID'"}'
```
cycle-uuid는 `plane cycles ls --format json`의 `id`.

### 3-3. 연속 쓰기 직후 일시적 실패 (rate-limit)
빠르게 5건 이상 연속 `update`/`mv`를 돌리면 일부가 조용히 실패할 수 있습니다.
**개별로 재시도하면 성공**합니다. 배치 루프는 결과를 검증하고 실패분만 다시 돌리도록 설계하세요.

### 3-4. `tomllib` 부재 (시스템 python < 3.11)
config.toml 토큰을 파싱할 때 `import tomllib`가 깨질 수 있습니다. 안전하게:
```bash
KEY=$(grep -E '^api_key' ~/.plane-cli-requiem/config.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
```

### 3-5. 깨진 듯한 출력은 보통 인코딩 표시일 뿐
git이 한글 경로를 8진 escape로 보여주면 `git -c core.quotepath=false ...`. CLI 출력은
`--format json`으로 받아 `python3`/`jq`로 파싱하면 결정론적입니다.

---

## 4. 자주 쓰는 레시피

```bash
# 전체 이슈(잘림 없이) — 표시 제한 우회 위해 json으로 받기
"$PCR" ls --project AUTOPLAN --format json | python3 -c '
import sys,json
for w in sorted(json.load(sys.stdin),key=lambda x:x["id"]):
    print(f"{w[\"id\"]:<12}{w[\"priority\"]:<7}{w[\"state\"]}")'

# 모듈/사이클 멤버십 검증 (이름으로 항목 나열)
"$PCR" modules ls "인력/자격 시스템 (Quali-fit Core)" --format json
"$PCR" cycles  ls "Sprint 1" --format json

# 여러 항목 일괄 변경
"$PCR" bulk AUTOPLAN-7 AUTOPLAN-8 --priority low --state Backlog

# 상세(AC·댓글·활동), 생성, 댓글
"$PCR" show AUTOPLAN-1
"$PCR" create "새 작업" --priority high --state Todo
"$PCR" comment AUTOPLAN-1 post "진행 상황 업데이트"
```

쓰기 전 **dry-run 미리보기**가 필요하면 `update`/`bulk`에 `--dry-run` 플래그가 있습니다.

---

## 5. raw API 탈출구 요약

CLI가 못 하거나 버그가 있을 때 쓰는 엔드포인트(전부 `X-API-Key` 헤더):

| 작업 | 메서드 · 경로 | 비고 |
|------|---------------|------|
| 프로젝트 기능 토글 | `PATCH /workspaces/{slug}/projects/{pid}/` | `{"cycle_view":true}` 등 |
| 사이클 생성 | `POST /workspaces/{slug}/projects/{pid}/cycles/` | 본문에 `project_id` 필수 |
| 사이클 날짜 수정 | `PATCH .../cycles/{cid}/` | 본문에 `project_id` 동봉 권장 |
| 토큰 유효성 교차검증 | `GET /workspaces/{slug}/projects/` | 200이면 유효 |

> 공식 API 스키마는 크레이트의 `docs/plane-api-reference.md`에 있지만, **이 자체 호스팅
> 서버 버전과 필드 요구사항이 다를 수 있습니다**(예: cycle 생성 시 `project_id` 본문 요구).
> 막히면 raw 응답 본문을 그대로 출력해 진짜 에러를 확인하세요 — 표면 메시지를 믿지 마세요.

---

## 6. 빠른 참조 (이 인스턴스)

- workspace slug: `kiba`
- 프로젝트: `AUTOPLAN`(업무 자동화 기획, 실데이터), `KIBA`(Plane 데모)
- base URL: `https://plane.bit-habit.com` (env `PLANE_API_URL`)
- 토큰: `~/.plane-cli-requiem/config.toml` — **절대 커밋/출력 금지**, 노출 시 회전
