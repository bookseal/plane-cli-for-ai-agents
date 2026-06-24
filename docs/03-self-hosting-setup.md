# 03. 자체 호스팅 셋업

대상: `plane-cli-requiem` (Rust, crates.io). 자체 호스팅 인스턴스
`https://plane.bit-habit.com`에 붙이는 방법.

## 0) 설치

Rust 툴체인이 없다면 먼저 [rustup](https://rustup.rs):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# 새 셸을 열거나:  source "$HOME/.cargo/env"
```

CLI 설치:

```bash
cargo install plane-cli-requiem
```

## 1) 핵심: `PLANE_API_URL`로 API 베이스 바꾸기

`plane-cli-requiem`은 공식 문서엔 안 적혀 있지만, 환경변수 **`PLANE_API_URL`**로
API 베이스 주소를 바꿀 수 있습니다. 소스 `src/api/plane_api_client.rs`에서
`std::env::var("PLANE_API_URL")`로 읽습니다. 이후 URL은 다음 규칙으로 조립됩니다:

```
{PLANE_API_URL}/api/v1/workspaces/{slug}/...
```

즉 **이 변수 하나면 소스 패치 없이** 자체 호스팅에 동작합니다.

```bash
export PLANE_API_URL="https://plane.bit-habit.com"
```

매번 셸에서 쓰려면 `~/.zshrc`에 추가:

```bash
echo 'export PLANE_API_URL="https://plane.bit-habit.com"' >> ~/.zshrc
source ~/.zshrc
```

> 주의: 끝에 슬래시(`/`)를 붙이지 마세요. `.../v1//workspaces`처럼 이중 슬래시가 될 수 있습니다.

## 2) 워크스페이스 슬러그(slug) 찾기

slug는 워크스페이스를 식별하는 짧은 문자열입니다. 찾는 법:

- **웹 URL에서**: 로그인 후 주소창을 보세요.
  `https://plane.bit-habit.com/<slug>/projects/...`의 `<slug>`가 그것입니다.
- **워크스페이스 설정 페이지**: Workspace Settings → General에 표시됩니다.

## 3) API 토큰 발급

웹 UI → 우상단 프로필 → **Settings → API Tokens → Add API token**.

- 이름을 알아보기 쉽게 (예: `macbook-cli`, `agent-readonly`)
- **만료(expiry)를 짧게** 잡는 것을 권장 (에이전트용은 특히)
- 발급된 `plane_api_...` 토큰은 **한 번만** 보여집니다. 안전한 곳(비밀번호 관리자)에 보관하세요.
- ⚠️ **이 토큰을 절대 git에 커밋하지 마세요.**

## 4) CLI 설정

```bash
plane config --workspace <slug> --token plane_api_xxx
```

설정은 보통 `~/.config/.../config.toml` 류에 저장됩니다 (토큰 포함).
**이 파일은 커밋 금지** — 이 레포 `.gitignore`가 `config.toml`을 막아둡니다.

## 5) 연결 확인

```bash
plane me          # 내 사용자 정보(JSON) → 나오면 인증 성공
plane projects    # 프로젝트 목록
plane mine items  # 내게 할당된 이슈
```

`plane me`가 401/403이면 토큰/만료/권한을, 연결 오류면 `PLANE_API_URL`과
도메인 접근성(브라우저로 열리는지)을 확인하세요.

---

## 링크 패치 빌드

`plane open` / `plane url` / `plane info` 명령은 사람이 볼 **웹 링크**를 만드는데,
이 부분에 `app.plane.so`가 **하드코딩**되어 있습니다. 자체 호스팅에선 잘못된 링크가 나옵니다.
(이슈 조회/생성 등 다른 명령은 API 베이스만 쓰므로 정상 동작합니다.)

링크까지 고치려면 소스를 받아 도메인을 치환한 뒤 로컬 빌드합니다:

```bash
# 1. 소스 받기
git clone https://github.com/<requiem-repo>/plane-cli-requiem
cd plane-cli-requiem

# 2. 하드코딩된 도메인 치환 (macOS의 sed는 -i '' 필요)
grep -rl 'app.plane.so' src
sed -i '' 's#app\.plane\.so#plane.bit-habit.com#g' $(grep -rl 'app.plane.so' src)

# 3. 로컬 소스로 설치 (crates.io 버전 위에 덮어씀)
cargo install --path .
```

> 이건 **선택 사항**입니다. 링크 생성 명령을 안 쓴다면 `PLANE_API_URL`만으로 충분합니다.

다음: 이 CLI를 AI 에이전트의 도구로 노출하기 →
[04-ai-agent-integration.md](04-ai-agent-integration.md).
