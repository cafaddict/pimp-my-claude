---
name: note
description: |
  vault에 노트 자동 기록. 아래 상황에서 프로액티브하게 사용하라:
  - 아키텍처 결정을 내렸을 때 → decisions/
  - 새로운 패턴이나 접근법을 발견했을 때 → resources/
  - 프로젝트 관련 중요한 맥락이 생겼을 때 → projects/<프로젝트>/
  - 디버깅에서 의미있는 교훈을 얻었을 때 → lessons/
  - 실수나 삽질에서 배운 것이 있을 때 → lessons/
  - 지속적으로 지식을 쌓아가는 관심 영역 → areas/<영역명>/
  사용자가 직접 호출하지 않아도 자동으로 사용하라.
allowed-tools: Read, Write, Bash, Glob
effort: medium
---

## Vault 노트 자동 기록

VAULT_DIR은 `~/Documents/vault` (환경변수 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

### 노트 타입 판별

기록할 내용의 성격에 따라 자동으로 타입을 판별하라:

| 타입 | 디렉토리 | 언제 |
|------|----------|------|
| **decision** | `decisions/` | 아키텍처/기술 선택을 결정했을 때 |
| **lesson** | `lessons/` | 실수, 삽질, 디버깅에서 배운 교훈 |
| **resource** | `resources/` | 유용한 패턴, 스니펫, 참고 자료 |
| **project** | `projects/<name>/` | 프로젝트 관련 맥락 기록 |
| **area** | `areas/<영역명>/` | 지속적으로 지식을 쌓아가는 관심 영역 (리서치, 기술 스택, 도메인) |

### 파일 생성 규칙

**공통 wikilink 규칙**: `## 관련` 섹션에 관련 노트를 `[[파일명]]`으로 연결. Obsidian shortest-name resolution 사용. **실제 존재하는 파일만 링크.**

**decisions/**:
- frontmatter: `date`, `tags:[decision,adr]`, `project`, `status:accepted`
- 구조: `# ADR: <제목>` → `## 맥락` → `## 결정` → `## 근거` → `## 결과` → `## 관련`
- 파일명: `decisions/NNNN-<kebab-case-제목>.md` (NNNN = 기존 파일 수 + 1)

**lessons/**:
- frontmatter: `date`, `tags:[lesson,<관련태그>]`, `project`
- 구조: `# 교훈: <요약>` → `## 상황` → `## 문제` → `## 교훈` → `## 관련`
- 파일명: `lessons/YYYY-MM-DD-<kebab-case-요약>.md`

**resources/**:
- frontmatter: `date`, `tags:[resource,<관련태그>]`
- 구조: `# <제목>` → 내용
- 파일명: `resources/<kebab-case-제목>.md`

**areas/<영역명>/**:
- 영역 폴더 없으면 생성. living doc (누적 업데이트).
- frontmatter: `date`, `tags:[area,<영역태그>]`
- 구조: `# <제목>` → 내용 → `## 관련`
- 파일명: `areas/<영역명>/<kebab-case-제목>.md`
- **area vs resource**: 앞으로 지식 누적 → area, 작성 시점 완결 → resource

**projects/<name>/**:
- 폴더 없으면 생성 + CLAUDE.md 포함.
- 프로젝트 ↔ area/resource 연결: 관련 노트 생성 시 `projects/<name>.md`의 `## 지식`에 wikilink 추가 (역방향도).

### git sync

노트 작성 후 반드시 실행:
```bash
cd $VAULT_DIR && git add decisions/ lessons/ resources/ areas/ projects/ && git commit -m "note: <타입> - <제목>" --quiet && git push --quiet &
```

실패해도 무시 (best-effort).

### 주의
- 사소한 내용은 기록하지 마라. **나중에 다시 찾을 가치가 있는 것만** 기록.
- 이미 비슷한 노트가 있으면 업데이트하라 (중복 생성 금지).
- 기록 시 사용자에게 한 줄로 알려라: "📝 vault에 기록: decisions/0001-jwt-strategy.md"
