# plane-cli-for-ai-agents

자체 호스팅 [Plane](https://plane.so) (오픈소스 프로젝트 관리 툴)을 **CLI로 다루고**,
나아가 **AI 에이전트가 Plane을 1급 시민처럼 읽고 쓰게** 만드는 과정을 정리한 레포입니다.

- 대상 인스턴스: 자체 호스팅 Plane (`https://plane.bit-habit.com`, Ubuntu + k3s)
- 클라이언트: 맥북 (도메인이 공개라 인터넷으로 바로 연결, SSH 불필요)
- 최종 목적: 사람이 쓰는 같은 CLI를 그대로 AI 에이전트의 도구로 노출해, 에이전트가
  이슈를 만들고 댓글을 달고 사이클을 정리하게 만들기

---

## 왜 이 레포인가

Plane은 웹 UI가 훌륭하지만, **AI 에이전트는 클릭이 아니라 텍스트로 일합니다.**
에이전트에게 REST API를 직접 던지면 인증·페이징·에러 처리·URL 조립을 매번 새로
가르쳐야 하고, 권한을 좁히기도 어렵습니다. 대신 **잘 만든 CLI 하나를 도구로 감싸 주면**:

- 입출력이 텍스트(특히 `--format json`) → 에이전트가 결정론적으로 파싱
- 종료 코드(exit code)로 성공/실패 판단 → 루프·재시도 설계가 쉬움
- 셸 파이프(`| jq`, `| grep`)로 조합 가능 → 작은 명령을 엮어 큰 작업 수행
- 한 겹의 가드레일(허용 명령 화이트리스트, 최소권한 토큰)을 걸기 좋음

자세한 근거는 [docs/02-why-cli-for-ai-agents.md](docs/02-why-cli-for-ai-agents.md).

---

## 어떤 CLI를 쓰나 (혼동 주의)

"Plane CLI"라는 이름이 여러 개라 헷갈립니다. 정리하면:

| 이름 | 용도 | 우리한테 맞나 |
|------|------|---------------|
| 공식 **Prime CLI** | 서버 관리용 (`install`/`start`/`stop`). 로그인 개념 없음 | ❌ 운영용, 데이터 조작 X |
| **`plane-cli-requiem`** (Rust, crates.io) | 이슈 CRUD, `mine`, 사이클·모듈, 댓글, 관계, 대시보드. **JSON/CSV 출력** | ✅ 추천 |
| 공식 **Plane MCP Server** | 에이전트용 MCP 도구 서버 | 🟡 대안/병행 |

이 레포는 **`plane-cli-requiem`**을 기준으로 합니다.

---

## 빠른 시작 (자체 호스팅)

> 핵심: `plane-cli-requiem`은 문서엔 없지만 환경변수 **`PLANE_API_URL`**로 API 베이스 주소를
> 바꿀 수 있습니다. 이거 하나면 소스 패치 없이 자체 호스팅 인스턴스에 붙습니다.

```bash
cargo install plane-cli-requiem
export PLANE_API_URL="https://plane.bit-habit.com"
plane config --workspace <slug> --token plane_api_xxx
```

연결 확인:

```bash
plane me          # 내 사용자 정보가 JSON으로 나오면 성공
plane projects    # 프로젝트 목록
```

자동화 스크립트로 한 번에 하려면:

```bash
./setup-plane-cli.sh    # PLANE_INSTANCE_URL을 입력받아 설치/설정 안내
```

자세한 셋업(슬러그 찾는 법, 링크 패치 빌드 포함)은
[docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md).

---

## 알려진 한계 (자체 호스팅)

`plane open` / `plane url` / `plane info`는 코드에 `app.plane.so`가 **하드코딩**되어 있어
자체 호스팅에선 잘못된 웹 링크를 만듭니다. (나머지 명령은 정상 — API 베이스만 쓰기 때문.)
링크까지 고치려면 crate 소스에서 `app.plane.so`를 우리 도메인으로 치환한 뒤
`cargo install --path .`로 로컬 빌드하면 됩니다. 절차는
[docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md#링크-패치-빌드)에 있습니다.

---

## 전체 과정

1. **이해** — Plane이란 무엇이고 데이터 모델은 어떻게 생겼나
   → [docs/01-what-is-plane.md](docs/01-what-is-plane.md)
2. **왜 CLI인가 / 왜 에이전트인가**
   → [docs/02-why-cli-for-ai-agents.md](docs/02-why-cli-for-ai-agents.md)
3. **자체 호스팅 셋업** — `PLANE_API_URL`, 슬러그, 링크 패치
   → [docs/03-self-hosting-setup.md](docs/03-self-hosting-setup.md)
4. **AI 에이전트 통합** — CLI를 도구로 노출, MCP, 가드레일, 예시 루프
   → [docs/04-ai-agent-integration.md](docs/04-ai-agent-integration.md)
5. **데모** — 내 작업 스탠드업 요약
   → [examples/standup-summary.sh](examples/standup-summary.sh)
6. **실전 walkthrough** — 설치부터 첫 쓰기까지, 실제로 겪은 함정 기록
   → [docs/05-walkthrough.md](docs/05-walkthrough.md)
7. **CLI 함정과 레시피** — 에이전트가 막히는 지점(사이클 생성 버그, 기능 토글, raw API 우회)과 검증된 명령
   → [docs/06-cli-gotchas-and-recipes.md](docs/06-cli-gotchas-and-recipes.md)

---

## 보안 (꼭 읽기)

- **API 토큰을 절대 커밋하지 마세요.** `.gitignore`가 `.env`, `config.toml`, `*.token`을 막아두긴
  했지만, 최종 책임은 사람입니다. 커밋 전 `git grep -i plane_api_`로 확인하세요.
- 에이전트에게 줄 토큰은 **최소 권한 + 짧은 만료**를 권장합니다. 가능하면 읽기 위주로 시작하고,
  쓰기 권한은 별도 토큰으로 분리하세요.
- 자세한 가드레일은 [docs/04-ai-agent-integration.md](docs/04-ai-agent-integration.md#가드레일).

---

## 라이선스

[MIT](LICENSE)
