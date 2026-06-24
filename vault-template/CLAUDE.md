# Vault 운영 매뉴얼

이 디렉토리는 Obsidian vault이자 개인 지식 관리 시스템(Second Brain)이다.

## 구조

```
vault/
├── projects/       프로젝트별 지식
├── sessions/       Claude Code 세션 기록 (자동 생성)
├── areas/          지속 관리 영역 (커리어, 기술 스택, 학습 등)
├── resources/      참고 자료, 리서치 보고서
├── decisions/      ADR (아키텍처 의사결정 기록)
├── lessons/        교훈 (디버깅, 실수에서 배운 것)
├── templates/      노트 템플릿
└── daily-notes/    일일 노트 (YYYY-MM-DD.md)
```

## 규칙

### 노트 작성
- 모든 노트에 frontmatter(YAML) 필수 (아래 스키마 참고)
- 파일명: kebab-case (예: `jwt-token-refresh.md`)
- 내부 링크: `[[노트명]]` 형식 (Obsidian shortest-name resolution)
- 하나의 노트 = 하나의 개념/결정/기록
- **시간은 KST(한국시간) 기준**

### Frontmatter 스키마

| 필드 | session | decision | lesson | resource | daily | project |
|------|---------|----------|--------|----------|-------|---------|
| date | 필수 | 필수 | 필수 | 필수 | 필수 | 필수 |
| tags | 필수 | 필수 | 필수 | 필수 | 필수 | 필수 |
| summary | 필수 | 필수 | 필수 | 필수 | 필수 | - |
| project | 선택 | 필수 | 선택 | 선택 | - | - |
| topics | 필수 | - | - | 필수 | - | - |
| status | - | 필수 | - | - | - | 필수 |
| superseded_by | - | 조건부 | - | - | - | - |
| keywords | - | - | 필수 | - | - | - |
| confidence | - | - | 필수 | - | - | - |
| importance | - | - | 선택 | 선택 | - | - |
| cwd | 필수 | - | - | - | - | - |

- status 값: `proposed | accepted | deprecated | superseded`
- **superseded_by**: status=superseded일 때 `[[NNNN-후속결정]]`. 검색은 superseded를 강등/제외한다 (경량 forgetting).
- confidence 값: `high | medium | low` (사실의 확실성)
- importance 값: `high | medium | low` (재사용 가치 — 검색/브리핑 우선순위에 가중)
- **area 타입**은 위 표 외에 `sources`(출처 event 목록), `last_distilled`(YYYY-MM-DD), `importance`를 갖는다. 아래 Areas 섹션 참고.

### 내용 깊이
- **Session**: "무엇을 했다" + "왜/무엇을 배웠다" 반드시 병기. `## 핵심 인사이트` 필수.
- **Decision**: 최소 2개 대안 비교 테이블 + `## 트레이드오프` 필수.
- **Lesson**: `## 적용 방법` 필수 (다음에 같은 상황이면?).
- **Resource**: `## 핵심 요약` + `## 관련` 필수.
- **Area(entity)**: 모든 사실 주장에 `(출처: [[event]])` 필수. 모순은 `## 미해결/모순`에.
- Obsidian callout (`> [!tip]`, `> [!warning]`)으로 핵심 강조.

## Areas — Entity/Concept 레이어

vault는 두 레이어로 나뉜다:
- **event 로그** (sessions/lessons/decisions) — 시간순·불변. "언제 무슨 일이 있었나." 긴 세션의 context pollution을 막는 1차 기록.
- **entity 페이지** (`areas/<도메인>/<개념>.md`) — 개념순·가변(living). "X가 무엇인가 (현재 최선의 이해)." event를 **삭제하지 않고 참조**하며, 지식을 작성 시점에 한 번 압축해 복리시킨다.

`/vault-distill`이 event → entity로 합성·갱신한다.

| 타입 | 시간축 | 단위 | 예시 |
|------|--------|------|------|
| **area (entity)** | 지속·갱신 | 개념/도메인 | `areas/harness-engineering/feedback-loop.md` |
| lesson | 일회성 | 특정 상황/실수 | `lessons/2026-06-24-link-validation.md` |
| resource | 작성시점 완결 | 외부 참고 | `resources/obsidian-plugin-guide.md` |
| decision | 일회성 선택 | 특정 결정(ADR) | `decisions/0003-embedding-provider.md` |

### Area frontmatter
```yaml
date: <최초 작성일>
tags: [area, <도메인태그>]
summary: <1문장 — 이 개념이 무엇인가>
importance: low | medium | high
confidence: low | medium | high
sources: [[YYYY-MM-DD-...]], [[NNNN-...]]   # 합성 출처 event
last_distilled: YYYY-MM-DD
```

### Area 규칙
- 한 페이지 = 한 개념. 파일명 `areas/<도메인>/<개념>.md` (kebab-case).
- **출처 추적성 필수**: 모든 사실 주장에 `(출처: [[event]])` — 환각이 ground-truth로 굳는 것 방지.
- 모순은 지우지 말고 `## 미해결/모순`에 명시.
- area ↔ project 양방향 링크 (`projects/<name>.md`의 `## 지식`에 역링크).

### 파일명 규칙
| 타입 | 형식 | 예시 |
|------|------|------|
| Session | `sessions/YYYY-MM-DD-HHMM-<topic>.md` | `sessions/2026-04-06-2312-harness-audit.md` |
| Daily | `daily-notes/YYYY-MM-DD.md` | `daily-notes/2026-04-06.md` |
| Decision | `decisions/NNNN-<제목>.md` | `decisions/0003-embedding-provider.md` |
| Lesson | `lessons/YYYY-MM-DD-<요약>.md` | `lessons/2026-04-06-link-validation.md` |
| Resource | `resources/<제목>.md` | `resources/obsidian-plugin-guide.md` |
| Area | `areas/<영역>/<제목>.md` | `areas/harness-engineering/feedback-loop.md` |
| Project | `projects/<이름>.md` | `projects/pimp-my-claude.md` |

## Wikilink 규칙

Obsidian 그래프 뷰를 위해 노트 간 `[[wikilink]]`로 연결한다.

### 링크 무결성
- **링크 전 검증**: Glob으로 파일 존재 확인. 존재하지 않으면 절대 링크하지 마라.
- **고아 노트 금지**: 모든 노트는 `## 관련`에 최소 1개 wikilink 필수.
- **양방향 링크**: A에서 B를 링크하면, B의 `## 관련`에도 A를 추가.

### 연결 방향
- **Session** → Project (`[[프로젝트명]]`), Lesson (`[[교훈제목]]`)
- **Daily** → Sessions (`[[YYYY-MM-DD-HHMM-topic]]`), Decisions, Lessons, Resources
- **Daily 생성 후** → 각 Session의 `## 관련`에 `[[YYYY-MM-DD]]` 역링크 추가
- **Lesson** → Session, Project
- **Decision** → Project
- **Resource** → Project, 관련 Resource/Area
- **Project** → Sessions, Decisions, Lessons, Resources (역링크 모음)

**주의**: Session에서 daily note를 직접 링크하지 마라 — daily가 session을 역링크한다.

## MCP
이 vault는 markdown-vault-mcp를 통해 Claude Code에서 검색 가능.
- 검색: keyword (기본), hybrid (embedding 활성화 시)
- frontmatter 필터: tags, date, project, status, topics, confidence, keywords
