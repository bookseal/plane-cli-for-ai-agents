# 04. AI 에이전트 통합

목표: 사람이 쓰는 `plane` CLI를 **그대로 AI 에이전트의 도구**로 노출해서,
에이전트가 이슈를 읽고/만들고/코멘트하게 만들기. 단, 안전하게.

## 두 가지 통합 경로

### A) CLI를 에이전트의 셸 도구로 노출 (가장 단순)

대부분의 코딩 에이전트(예: Claude Code)는 셸 명령을 실행할 수 있습니다.
`PLANE_API_URL`과 토큰이 설정된 환경이라면, 에이전트는 바로 이렇게 씁니다:

```bash
plane mine items --format json
plane ls --project <slug> --format json
plane create "이슈 제목" --project <slug> --description "..."
plane comment post <NRO-123> "코멘트 내용"
```

> 실제 명령 이름 (plane-cli-requiem v0.3.3 기준):
> - 읽기: `plane ls`, `plane show <ID>`, `plane mine items`, `plane projects`, `plane me`, `plane comment ls <ID>`, `plane dashboard`
> - 쓰기: `plane create <제목>`, `plane update <ID> --state ...`, `plane done <ID>`, `plane comment post <ID> "..."`, `plane bulk <ID...>`, `plane delete <ID>`
> - 출력은 파이프로 넘기면 자동으로 JSON입니다(`--format json`은 명시해도 됨).

에이전트에게 시스템 프롬프트로 알려줄 것:

- **항상 `--format json`을 붙여라** (결정론적 파싱).
- **쓰기 명령(`create`/`update`/`delete`)은 실행 전에 사람 확인을 받아라.**
- 허용된 하위 명령 목록(아래 화이트리스트)만 사용해라.

### B) MCP (Model Context Protocol)

공식 **Plane MCP Server**를 쓰면, CLI 대신 구조화된 MCP 도구로 노출됩니다.
스키마가 명시적이라 에이전트가 인자를 덜 틀립니다. CLI 경로와 병행/대체 가능합니다.

- 장점: 도구 스키마·권한이 명시적, 출력이 구조화됨
- 단점: 별도 서버 운영, 셸 조합성(파이프)은 약함
- 선택 기준: **빠른 셸 자동화 → CLI**, **여러 에이전트/엄격한 스키마 → MCP**

또는 `plane-cli-requiem`을 감싸는 **얇은 MCP 래퍼**를 직접 만들어, 허용 명령만
도구로 등록하는 방법도 있습니다 (CLI의 조합성 + MCP의 명시성).

## 가드레일

에이전트가 Plane을 망가뜨리지 않게 하는 최소 장치들:

### 1) 최소 권한 토큰 + 짧은 만료

- 에이전트 전용 토큰을 사람 토큰과 **분리**하세요.
- 가능하면 **읽기 우선**으로 시작 (조회/요약). 쓰기는 신뢰가 쌓인 뒤.
- **만료를 짧게** 잡고 주기적으로 회전(rotate)하세요.
- 토큰은 환경변수/시크릿 매니저로만 주입. **프롬프트·로그·커밋에 남기지 마세요.**

### 2) 명령 화이트리스트

에이전트가 부를 수 있는 하위 명령을 명시적으로 제한합니다. 예:

```
허용 (읽기):  plane me, plane projects, plane ls, plane mine items, plane show
허용 (쓰기):  plane comment post       # 코멘트는 비교적 안전
금지:         plane delete --yes, plane bulk, 대량 update
```

읽기 전용 토큰을 쓰면 화이트리스트가 깨져도 서버 측에서 한 번 더 막힙니다 (이중 방어).

### 3) 사람-확인 루프 (human-in-the-loop)

쓰기 작업은 **제안 → 사람 승인 → 실행** 순서로. 에이전트는 실행할 명령을 출력만 하고,
사람이 승인한 것만 셸로 넘기는 패턴이 안전합니다.

### 4) 변경 추적

에이전트가 만든/바꾼 이슈에는 일관된 라벨(예: `agent`)이나 코멘트 서명을 남겨,
나중에 사람이 필터링·롤백할 수 있게 하세요.

## 예시 에이전트 루프 (의사 코드)

"매일 아침, 내 미완료 이슈를 요약하고, 3일 이상 안 움직인 이슈에 리마인더 코멘트 제안":

```
1. items = run("plane mine items --format json")        # 읽기
2. stale = items에서 updated_at이 3일 이전인 것 필터       # LLM/jq
3. summary = LLM이 stale을 사람이 읽을 요약으로 정리        # 추론
4. 사용자에게 summary + 제안 코멘트 목록 제시               # human-in-the-loop
5. 사용자가 승인한 항목만:
     run("plane comment post <NRO-123> '리마인더: ...'")  # 쓰기 (승인 후)
```

읽기(1)는 자유롭게, 쓰기(5)는 승인 후에만 — 이 경계가 핵심입니다.

## 실전 데모

내 작업 스탠드업 요약 스크립트:
[../examples/standup-summary.sh](../examples/standup-summary.sh).
이 스크립트의 `jq` 파이프라인은 직접 채워보도록 `TODO(human)`으로 남겨두었습니다.
