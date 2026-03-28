# Vault 운영 매뉴얼

이 디렉토리는 Obsidian vault이자 개인 지식 관리 시스템(Second Brain)이다.

## 구조

```
vault/
├── projects/       프로젝트별 지식 (각 프로젝트에 CLAUDE.md 포함)
├── sessions/       Claude Code 세션 기록 (자동 생성)
├── areas/          지속 관리 영역 (커리어, 기술 스택, 학습 등)
├── resources/      참고 자료, 스니펫, 북마크
├── decisions/      ADR (아키텍처 의사결정 기록)
├── templates/      노트 템플릿
└── daily-notes/    일일 노트 (YYYY-MM-DD.md)
```

## 규칙

### 노트 작성
- 모든 노트에 frontmatter(YAML) 포함: tags, date, project(해당 시)
- 파일명: kebab-case (예: `jwt-token-refresh.md`)
- 내부 링크: `[[노트명]]` 형식으로 연결
- 하나의 노트 = 하나의 개념/결정/기록

### 세션 노트 (sessions/)
- 자동 생성됨 (Stop hook)
- 수동 수정 가능
- 형식: `sessions/YYYY-MM-DD-<요약>.md`

### 프로젝트 노트 (projects/)
- 프로젝트당 하나의 폴더
- 각 폴더에 CLAUDE.md로 프로젝트 맥락 기술
- 코드는 여기에 두지 않음 — 메타 정보, 결정, 세션 기록만

### 의사결정 (decisions/)
- ADR 형식: `decisions/NNNN-<제목>.md`
- 템플릿: `templates/decision.md` 참고

## MCP
이 vault는 markdown-vault-mcp를 통해 Claude Code에서 시맨틱 검색 가능.
- 검색: vault 내 노트를 의미 기반으로 검색
- 읽기/쓰기: 노트 생성, 수정, 조회
