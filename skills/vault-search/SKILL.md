---
name: vault-search
description: "vault 전체 검색 (decisions, lessons, areas, resources, projects). sessions는 /recall 사용."
argument-hint: "[keyword] [--type decision|lesson|resource|area|project] [--project name] [--recent N]"
effort: high
---

## Vault 검색 프로토콜

VAULT_DIR: `$CLAUDE_VAULT_DIR` (미설정 시 `~/Documents/vault`)

vault가 없으면 사용자에게 `setup.sh --with-vault`로 생성하라고 안내하고 종료.

**주의**: sessions/는 검색하지 않는다. 세션 복원은 `/recall` 사용.

### 1. 인수 파싱

`$ARGUMENTS`에서 다음을 추출:
- **keyword**: 검색어 (필수). 없으면 "검색어를 입력해주세요" 안내 후 종료
- **--type**: 필터 (decision, lesson, resource, area, project). 생략 시 전체
- **--project**: 프로젝트명 필터. 프론트매터의 `project` 태그와 매칭
- **--recent N**: 최대 결과 수 (기본 10)

### 2. 검색 대상 매핑

| --type 값 | 디렉토리 | glob 패턴 |
|-----------|----------|-----------|
| decision | `$VAULT_DIR/decisions/` | `*.md` |
| lesson | `$VAULT_DIR/lessons/` | `*.md` |
| resource | `$VAULT_DIR/resources/` | `*.md` |
| area | `$VAULT_DIR/areas/` | `**/*.md` |
| project | `$VAULT_DIR/projects/` | `**/*.md` |
| (미지정) | 위 5개 전부 | `**/*.md` |

검색에서 제외: `.gitkeep`, `CLAUDE.md`, `templates/`

### 3. 검색 실행

우선순위:
1. vault MCP 서버가 연결되어 있으면 → 시맨틱 검색 (대상 디렉토리 스코프)
2. MCP 없으면 → Grep으로 keyword 검색 (대상 디렉토리 내 `*.md` 파일)

keyword가 빈 문자열이고 --type만 지정된 경우 → 해당 디렉토리의 파일 목록을 Glob으로 조회 (브라우징 모드)

--project 필터가 있으면: 검색 결과 중 프론트매터에 `project: <name>`이 포함된 것만 남긴다.

결과를 날짜 기준 최신순 정렬, --recent N개로 제한.

### 4. 결과 요약 표시

각 결과 파일에서 추출:
- **제목**: 첫 번째 `# ` 헤딩
- **날짜**: 프론트매터 `date` 필드
- **태그**: 프론트매터 `tags` 필드
- **타입**: 디렉토리 경로로 추론 (decisions/ → decision, lessons/ → lesson, ...)
- **발췌**: 헤딩 다음 첫 2-3줄 내용 (100자 이내)
- **wikilink**: `[[파일명-확장자제외]]`

표시 형식:

```
## 검색 결과: "keyword" (N건)

1. **[[0001-vault-integration-pattern-b]]** (decision, 2026-03-28)
   tags: decision, adr | project: pimp-my-claude
   > Vault 통합은 패턴 B (agent → summary 반환 → skill이 /note 호출)

2. **[[2026-03-28-stop-hook-runs-every-turn]]** (lesson, 2026-03-28)
   tags: lesson, claude-code, hooks
   > Stop hook은 매 턴마다 실행된다 — SessionEnd가 아님
```

결과가 없으면:
- 검색어 변형 제안 (동의어, 한/영 변환, 관련 키워드)
- vault가 비어 있으면 `/note`로 기록부터 시작하라고 안내

### 5. 상세 조회

"번호를 선택하면 전체 내용을 보여드립니다." 라고 안내.

사용자가 번호를 선택하면:
1. 해당 파일을 Read로 전체 내용 표시
2. `## 관련` 섹션의 wikilink가 있으면 연결된 노트도 안내
