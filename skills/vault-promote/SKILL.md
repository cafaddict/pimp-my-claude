---
name: vault-promote
description: "vault의 lessons/ 에서 반복되는 교훈을 프로젝트 .claude/rules/ 로 승격 제안. 죽은 지식을 살아있는 rule로."
allowed-tools: Read, Grep, Glob, Bash, Write
effort: medium
---

## Memory → Rule 승격

`lessons/`에 쌓인 교훈 중 반복 등장하는 주제를 탐지하여, 프로젝트 `.claude/rules/` 에 rule로 승격 제안한다.
Windsurf/Cursor Bugbot의 Learned Rules 패턴.

### 프로세스

1. **스캔**
   - `$CLAUDE_VAULT_DIR/lessons/` 전체 `.md` 읽기 (기본: `~/Documents/vault/lessons/`)
   - 프로젝트 필터가 주어지면 `project:` frontmatter로 매칭

2. **주제 빈도 분석**
   - frontmatter의 `tags`, `keywords` 필드 집계
   - 본문에서 반복 등장하는 도구명/패턴명/기술명 추출
   - **3회 이상 등장하는 주제**만 후보로 유지

3. **중복 제거**
   - 대상 `.claude/rules/` 또는 `~/.claude/rules/` 에 이미 같은 주제가 있으면 스킵
   - 기존 rule과 부분 중복이면 "확장 제안"으로 분류

4. **제안 생성**
   각 후보 주제에 대해:
   - 해당 lesson 파일들 링크 (wikilink)
   - 공통 패턴 요약
   - `.claude/rules/<topic>.md` 초안 작성 (10~30줄)

5. **사용자 승인**
   - 제안 리스트를 표로 출력: `주제 | 근거 lesson 수 | 초안 경로`
   - 사용자가 "전부 승인" / "N번만" / "취소" 선택
   - 승인된 것만 `.claude/rules/` 에 실제 Write

### 사용 예
```
/vault-promote                  # 전체 lessons 스캔
/vault-promote --project autotrade  # 특정 프로젝트만
/vault-promote --min-count 5    # 최소 등장 횟수 조정
```

### 주의
- rule 파일은 **짧고 구체적**이어야 함 (10~30줄). 긴 에세이는 lesson에 남기고 rule에는 행동 지침만.
- 생성된 rule은 즉시 활성화되므로 사용자가 반드시 검토해야 함.
- 이미 CLAUDE.md에 반영된 내용은 rule로 중복 생성하지 않음.

### 관련
- `/vault-note` — 새 교훈 기록
- `/vault-search` — lessons 검색
