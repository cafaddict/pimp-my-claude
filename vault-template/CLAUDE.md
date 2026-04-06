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
| keywords | - | - | 필수 | - | - | - |
| confidence | - | - | 필수 | - | - | - |
| cwd | 필수 | - | - | - | - | - |

- status 값: `proposed | accepted | deprecated | superseded`
- confidence 값: `high | medium | low`

### 내용 깊이
- **Session**: "무엇을 했다" + "왜/무엇을 배웠다" 반드시 병기. `## 핵심 인사이트` 필수.
- **Decision**: 최소 2개 대안 비교 테이블 + `## 트레이드오프` 필수.
- **Lesson**: `## 적용 방법` 필수 (다음에 같은 상황이면?).
- **Resource**: `## 핵심 요약` + `## 관련` 필수.
- Obsidian callout (`> [!tip]`, `> [!warning]`)으로 핵심 강조.

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
