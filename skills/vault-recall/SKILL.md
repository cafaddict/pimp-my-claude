---
name: vault-recall
description: "이전 세션 컨텍스트 복원. 새 세션 시작 시 사용. vault에서 시맨틱 검색."
argument-hint: "[검색 키워드]"
allowed-tools: Read, Grep, Glob, Bash, mcp__vault__search
effort: high
---

## 컨텍스트 복원 프로토콜

VAULT_DIR은 `$PIMP_MY_VAULT_DIR` 또는 `$CLAUDE_VAULT_DIR`, 없으면 `~/Documents/vault`이다.

### 0. 자동 동기화

컨텍스트를 복원하기 전에 최신 vault를 가져온다.
```bash
{{REPO_DIR}}/bin/vault-sync.sh --pull
```
sync 충돌·실패는 무시하지 말고 중단해 사용자에게 알린다.

### 1. vault에서 관련 세션 검색

$ARGUMENTS를 키워드로 vault의 sessions/ 디렉토리에서 관련 노트를 검색하라.

검색 방법 (우선순위):
1. vault MCP 서버가 연결되어 있으면 `mcp__vault__search(query, type_filter: "session")` 사용
2. MCP가 없으면 `sessions/` 디렉토리를 Grep으로 키워드 검색

여러 세션이 매칭되면 `recency × relevance`로 가중해 가장 관련 깊은 것부터 제시한다(세션은 importance 필드가 없으므로 최신성·일치도 중심). 개념 지식이 필요하면 `areas/`의 entity 페이지(`/vault-search`)도 함께 참고하라.

### 2. 관련 세션에서 추출

발견된 세션 노트에서 다음을 추출:
- **작업 내용**: 무엇을 했는가
- **결정사항**: 어떤 결정을 내렸는가
- **남은 TODO**: 완료되지 않은 작업
- **변경 파일**: 어떤 파일을 수정했는가

### 3. 현재 상태와 대조

- `git log --oneline -10`으로 최근 커밋 확인
- `git diff --stat`으로 현재 변경사항 확인
- 세션 노트의 TODO와 현재 코드 상태 비교

### 4. 컨텍스트 요약 제시

사용자에게 복원된 컨텍스트를 간결하게 요약:

```
## 이전 세션 요약
- **날짜**: [날짜]
- **작업**: [한 줄 요약]
- **결정**: [핵심 결정 1-2개]
- **남은 TODO**: [미완료 항목]
- **현재 상태**: [git 상태 기반]
```

### 5. 확인

"이 컨텍스트로 이어서 진행할까요?" 라고 물어라.

세션 기록이 아닌 결정/교훈/리소스는 `/vault-search`를 사용하라.
