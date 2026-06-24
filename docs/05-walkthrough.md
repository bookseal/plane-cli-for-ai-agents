# 05. 실전 walkthrough — 설치부터 첫 쓰기까지 (실측 기록)

이 문서는 자체 호스팅 인스턴스(`https://plane.bit-habit.com`, 워크스페이스 `kiba`)에
`plane-cli-requiem` **v0.3.3**을 실제로 붙여보며 겪은 과정과 함정을 그대로 정리한 것입니다.
다른 문서가 "이렇게 하면 된다"라면, 이 문서는 "실제로 해보니 이랬다"입니다.

## 0. 한눈에 보는 결과

- 맥북에서 인터넷으로 자체 호스팅 Plane에 CLI로 연결 성공
- Claude Code(AI 에이전트)가 직접 이슈를 **읽고**(`plane ls`/`show`) **썼다**(`plane create`)
- 그 과정에서 **CLI의 거짓 신호 / 설정 함정 / 실제 JSON 스키마**를 raw API로 교차검증

## 1. 설치

```bash
# Rust 없으면 먼저
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

cargo install plane-cli-requiem      # → ~/.cargo/bin/plane (v0.3.3)
```

> ⚠️ **PATH 함정**: 로그인 셸이 아닌 환경(스크립트, 일부 자동화)에서는 `~/.cargo/bin`이
> PATH에 없어 `plane: command not found`가 날 수 있습니다. 확실히 하려면 풀 경로
> `~/.cargo/bin/plane`를 쓰거나, PATH에 `~/.cargo/bin`을 넣으세요.

## 2. API 베이스 설정

```bash
echo 'export PLANE_API_URL="https://plane.bit-habit.com"' >> ~/.zshrc
source ~/.zshrc
```

이 변수 하나로 패치 없이 자체 호스팅에 붙습니다. (근거: [03](03-self-hosting-setup.md))

## 3. 인증 — 여기서 가장 많이 헤맸다

### 함정 A: `--token`만 단독으로 주면 워크스페이스 토큰이 안 바뀐다

```bash
# ❌ 이렇게 하면 기존(폐기된) 토큰이 그대로 남는다
plane config --token plane_api_NEW

# ✅ 반드시 --workspace 와 함께 줘야 덮어쓴다
plane config --workspace kiba --token plane_api_NEW
```

토큰을 회전(rotate)한 뒤 갱신할 때 특히 주의. 새 토큰을 넣었는데 계속 403이면
십중팔구 이 문제입니다.

### 함정 B: `plane me`의 "authenticated"는 토큰 유효성이 아니다

```bash
plane me
# Auth: authenticated (workspace-scoped)   ← 이건 "로컬 설정이 있다"는 뜻일 뿐
```

`me`는 로컬 `config.toml`만 보고 답합니다. **토큰이 실제로 서버에서 유효한지는
확인하지 않습니다.** 그래서 `me`는 통과하는데 `create`/`ls`는 403인 상황이 생깁니다.

### 진단 기법: raw API로 교차검증

CLI가 거짓 신호를 줄 때, 한 겹 아래의 REST를 직접 찔러 진실을 가립니다:

```bash
curl -sS -H "X-API-Key: plane_api_XXXX" \
  "https://plane.bit-habit.com/api/v1/workspaces/kiba/projects/" \
  -w "\n[http %{http_code}]\n"
# 200 → 토큰 자체는 유효 (문제는 CLI 설정)
# 403 {"detail":"Given API token is not valid"} → 토큰이 폐기/오타
```

설정 파일 위치와 형태(토큰은 절대 커밋 금지):

```toml
# ~/.plane-cli-requiem/config.toml
active_workspace = "kiba"

[workspaces.kiba]
api_key = "plane_api_..."
default_project = "autoplan"
```

### 토큰은 한 번만 — 매번 넣지 않는다

토큰은 위 파일에 **영구 저장**되어 셸/재부팅과 무관하게 재사용됩니다. 다시 넣어야 하는 건
오직: 토큰 폐기/회전, 만료, 새 워크스페이스 추가, 새 기기. 이 "장기 자격증명 1회 저장 →
무인 재사용" 모델이 바로 **AI 에이전트가 사람 개입 없이 도는** 토대입니다.

## 4. 읽기 — 실제 JSON 스키마

```bash
plane projects                       # 프로젝트 목록 (identifier가 --project 값)
plane ls --project AUTOPLAN --format json
```

> ⚠️ **스키마 함정**: 문서/직관과 달리 이 CLI의 이슈 JSON은 **평평**합니다.
> `state`/`priority`는 객체가 아니라 **문자열**입니다.

```json
{ "id": "AUTOPLAN-3", "title": "...", "state": "Backlog", "priority": "None", "due": null }
```

그래서 jq는 `.state.name`이 아니라 `.state`, 제목은 `.name`이 아니라 `.title`:

```bash
plane ls --project AUTOPLAN --format json \
  | jq -r 'sort_by(.id) | .[] | "  \(.id)  [\(.state)] \(.title)"'
```

> 또 다른 함정: `plane mine`은 기본 프로젝트가 없으면 "no default project" 오류.
> 한 번 `plane config --project AUTOPLAN`으로 지정하면 됩니다.

## 5. 쓰기 — 에이전트가 실제로 이슈를 만든다

```bash
plane create "Test" --project AUTOPLAN
# → Created AUTOPLAN-9: Test

plane show AUTOPLAN-9
#   State: Backlog  / Priority: —  / Assignees: 0
```

이게 핵심 시연입니다: **사람이 클릭한 게 아니라, 에이전트가 명령으로 이슈를 생성**했고
`plane show`로 검증했습니다. (정리용으로 `plane delete AUTOPLAN-9 --yes`로 제거 가능.)

## 6. 발견한 자체 호스팅 한계

- `plane open` / `url` / `info` : 웹 링크에 `app.plane.so`가 하드코딩 → 자체 호스팅에선
  잘못된 링크. (다른 명령은 정상.) 고치려면 소스 치환 후 빌드 — [03](03-self-hosting-setup.md#링크-패치-빌드)
- `plane show`의 **Relations**가 `unavailable (internal API may not support API key auth)`로
  뜸 — 일부 내부 API는 API Key 인증을 지원하지 않을 수 있음. 관계 그래프가 필요하면
  이 제약을 감안하세요.

## 7. 교훈 요약 (에이전트 도구화 관점)

1. **추상화의 거짓 신호를 의심하라.** `me`의 "authenticated"처럼, 편의 명령은 로컬 상태만
   볼 수 있다. 결정적 순간엔 raw API로 ground truth를 확인.
2. **스키마는 추측하지 말고 한 번 찍어 고정하라.** `... --format json | jq '.[0]'`로
   실제 필드명을 보고 파서를 맞춘다(여기선 `.title`, 문자열 `.state`).
3. **자격증명은 1회 저장·무인 재사용**이지만, 그래서 그 파일이 곧 열쇠다 — 최소권한·짧은
   만료·평문 노출 금지.
4. **읽기는 자유롭게, 쓰기는 검증과 함께.** `create` 후 `show`로 확인하는 루프가 안전하다.
