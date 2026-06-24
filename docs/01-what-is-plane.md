# 01. Plane이란 무엇인가

## 한 문장 요약

**Plane**은 Jira/Linear의 오픈소스 대안으로, 이슈 추적·스프린트(사이클)·로드맵·문서를
한곳에서 다루는 프로젝트 관리 도구입니다. **자체 호스팅**이 가능해서 데이터를 내 서버에
둘 수 있습니다 (이 레포는 `https://plane.bit-habit.com`, Ubuntu + k3s 인스턴스를 씁니다).

## 데이터 모델

CLI와 API를 이해하려면 객체 계층을 알아야 합니다. URL이 곧 이 계층을 따라갑니다:

```
Workspace (워크스페이스, 조직 단위 — slug로 식별)
└── Project (프로젝트)
    ├── Issue (이슈 — 가장 기본 작업 단위)
    │   ├── State        (상태: Backlog / Todo / In Progress / Done / Cancelled)
    │   ├── Assignee     (담당자)
    │   ├── Label        (라벨)
    │   ├── Comment      (댓글)
    │   └── Relation     (관계: blocks / blocked_by / duplicate / relates_to)
    ├── Cycle  (사이클 — 기간이 있는 스프린트. 이슈를 묶음)
    └── Module (모듈 — 기능/주제 단위로 이슈를 묶음)
```

핵심 포인트:

- **Workspace는 `slug`로 식별됩니다.** 예: `https://plane.bit-habit.com/my-team/...`의 `my-team`.
  CLI 설정(`plane config --workspace <slug>`)에 들어가는 값이 바로 이 slug입니다.
- **Issue가 중심**입니다. 대부분의 에이전트 작업은 이슈를 만들고/조회하고/상태를 바꾸고/댓글을
  다는 것으로 표현됩니다.
- **Cycle vs Module**: Cycle은 *시간*(이번 주 스프린트), Module은 *주제*(결제 기능)로 묶습니다.
  하나의 이슈가 동시에 둘 다에 속할 수 있습니다.

## API URL이 계층을 그대로 따른다

`plane-cli-requiem`이 호출하는 REST 경로는 이렇게 조립됩니다:

```
{PLANE_API_URL}/api/v1/workspaces/{slug}/projects/{project_id}/issues/...
```

그래서 `PLANE_API_URL` 하나만 자체 호스팅 도메인으로 바꾸면 나머지 경로는 규칙대로
완성됩니다. 이 점이 [03-self-hosting-setup.md](03-self-hosting-setup.md)의 핵심입니다.

## 왜 이걸 CLI/에이전트로 다루나

웹 UI는 사람이 한 번에 하나씩 클릭하기엔 좋지만:

- "이번 사이클에서 내게 할당된 미완료 이슈를 매일 아침 요약" 같은 **반복 작업**엔 비효율적
- "회의록에서 액션 아이템 10개를 이슈로 일괄 생성" 같은 **대량 작업**엔 손이 많이 감
- 무엇보다 **AI 에이전트는 클릭하지 못함** — 텍스트 인터페이스가 필요

→ 다음 문서에서 "왜 CLI이고 왜 에이전트인가"를 다룹니다:
[02-why-cli-for-ai-agents.md](02-why-cli-for-ai-agents.md).
