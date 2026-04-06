---
globs: ["**/vault/**/*.md", "**/Documents/vault/**"]
---
## Vault 노트 품질 기준

### Frontmatter 필수 필드
모든 vault 노트에 YAML frontmatter 필수. 타입별 요구사항:

| 필드 | session | decision | lesson | resource | daily | project |
|------|---------|----------|--------|----------|-------|---------|
| date | 필수 | 필수 | 필수 | 필수 | 필수 | 필수 |
| tags | 필수 | 필수 | 필수 | 필수 | 필수 | 필수 |
| summary | 필수 | 필수 | 필수 | 필수 | 필수 | - |
| project | 선택 | 필수 | 선택 | 선택 | - | - |
| topics | 필수 | - | - | 필수 | - | - |
| keywords | - | - | 필수 | - | - | - |
| confidence | - | - | 필수 | - | - | - |
| status | - | 필수 | - | - | - | 필수 |

### 내용 깊이
- Session: "무엇을 했다" + "왜/무엇을 배웠다" 반드시 병기. `## 핵심 인사이트` 섹션 필수.
- Decision: 최소 2개 대안 비교 테이블 + `## 트레이드오프` 분석 필수.
- Lesson: `## 적용 방법` 섹션 필수 (다음에 같은 상황이면?).
- Resource: `## 관련` 섹션에 최소 1개 wikilink 필수.
- Obsidian callout (`> [!tip]`, `> [!warning]`)으로 핵심 강조.

### 링크 무결성
- wikilink 전 Glob으로 대상 파일 존재 확인. 미존재 파일 링크 금지.
- 모든 노트에 `## 관련` 섹션, 최소 1개 wikilink (고아 노트 금지).
- 양방향 링크: A→B 링크 시 B의 `## 관련`에도 A 추가.
- Session에서 daily note(`[[YYYY-MM-DD]]`) 직접 링크 금지 — daily가 session을 역링크.
