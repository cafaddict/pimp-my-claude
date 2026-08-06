---
name: vault-distill
description: |
  event 노트(sessions/lessons/decisions)를 entity/concept 페이지(areas/)로 압축·합성. 지식을 시간순 로그가 아니라 개념별로 복리시킨다.
  사용 시점:
  - 같은 개념이 여러 세션·교훈에 반복 등장할 때
  - "X가 무엇인가"를 한 페이지로 정리해두고 싶을 때
  - 세션 종료 시 distill 후보를 발견했을 때 (프로액티브 제안)
argument-hint: "[개념/도메인 키워드]"
allowed-tools: Read, Write, Bash, Grep, Glob, mcp__vault__search
effort: high
---

## Vault Distill — event → entity 페이지 합성

VAULT_DIR은 `~/Documents/vault` (환경변수 `PIMP_MY_VAULT_DIR` 또는 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

event 로그(sessions/lessons/decisions, 시간순·불변)에서 "현재도 유효한 사실"만 뽑아 **개념당 1개 entity 페이지**(`areas/<도메인>/<개념>.md`, 가변·living)로 합성·갱신한다. RAG가 매번 chunk를 재조립하는 대신, 지식을 **작성 시점에 한 번 압축**해 복리시키는 것이 목적.

> [!tip] 지침 승격과의 차이
> 반복된 lesson을 프로젝트 지침으로 승격하는 일은 행동 규칙을 만든다. `/vault-distill`은 event → `areas/`로 누적되는 **개념 지식**을 만든다. 룰이 아니라 "X는 무엇인가"의 압축이면 distill한다.

### 1. 대상 개념 결정

`$ARGUMENTS`가 개념/도메인 키워드다. 비어 있으면:
- 최근 sessions/lessons를 훑어 **3회 이상 반복 등장**하는 개념을 후보로 제시하고 사용자에게 무엇을 distill할지 물어라.

도메인/개념을 정한다 → 목표 파일 경로 `areas/<도메인>/<개념>.md` (kebab-case).

### 2. 관련 event 수집

키워드로 event 노트를 검색:
1. vault MCP 서버가 있으면 `mcp__vault__search(query, type_filter)`를 session, lesson, decision마다 호출한다.
2. MCP 없으면 sessions/·lessons/·decisions/를 Grep.

각 event에서 그 개념에 대한 **사실·결정·교훈**을 추출. 출처 파일명을 반드시 기록한다(다음 단계 역링크용).

### 3. 기존 entity 페이지 머지

`areas/<도메인>/<개념>.md`가 이미 있으면 Read 후 **머지**(없으면 신규 생성):
- "현재도 유효한 사실"만 본문에 유지. 낡거나 번복된 내용은 갱신.
- **모순**(event 간, 또는 기존 페이지와 신규 event 간)은 지우지 말고 `## 미해결/모순` 섹션에 명시.
- 새로 추가된 출처를 `sources:`에 누적.

### 4. 출처 추적성 (필수)

> [!warning] 환각 방지 — provenance 강제
> entity 페이지는 합성물이라 환각이 ground-truth로 굳을 위험이 있다. **모든 사실 주장 끝에 `(출처: [[event-note]])`를 붙여라.** event → raw 2-hop 추적이 가능해야 한다.

- 링크 전 **Glob으로 출처 파일 존재 검증**(존재하지 않는 파일 링크 금지 — 기존 링크 무결성 규칙).
- 출처가 한 개도 없는 주장은 적지 마라.

### 5. 파일 형식

```markdown
---
date: {{최초 작성일}}
tags: [area, <도메인태그>]
summary: <1문장 — 이 개념이 무엇인가>
importance: low | medium | high
confidence: low | medium | high
sources: [[YYYY-MM-DD-...]], [[NNNN-...]]
last_distilled: YYYY-MM-DD
---

# <개념>

## 핵심
(이 개념의 현재 최선의 이해 — 각 주장에 (출처: [[..]]) 부착)

## 세부
(패턴/제약/예시. 출처 부착)

## 미해결/모순
(상충하는 주장이나 아직 확정 안 된 부분. 없으면 섹션 생략)

## 관련
%% 프로젝트, 관련 area/decision/lesson을 wikilink로. Glob 검증. 고아 금지. %%
```

- `last_distilled`는 이번 distill 날짜(KST)로 갱신.
- `importance`: 재사용 가치(자주 참조 = high). `confidence`: 사실의 확실성.

### 6. 양방향 링크

- entity ↔ 관련 프로젝트: `projects/<name>.md`의 `## 지식` 섹션에 이 entity wikilink 추가(역방향).
- `## 관련`에 최소 1개 wikilink (고아 금지).

### 7. 자동 동기화

생성·갱신한 entity와 프로젝트 노트의 정확한 경로를 넘겨 자동 동기화한다.
```bash
SYNC_PATHS=("$ENTITY_PATH")
[ -n "${PROJECT_NOTE_PATH:-}" ] && SYNC_PATHS+=("$PROJECT_NOTE_PATH")
{{REPO_DIR}}/bin/vault-sync.sh --commit "distill: <도메인>/<개념>" -- "${SYNC_PATHS[@]}"
```
충돌·sync 실패는 무시하지 말고 즉시 중단해 사용자에게 알린다.

### 8. 사용자에게 확인

생성/갱신된 entity 페이지 경로를 한 줄로 알려라: "🧪 distill: areas/<도메인>/<개념>.md (출처 N개 합성)". 모순이 있었으면 함께 보고.

### 주의
- **자동 write 금지** — 신규 개념 생성·대규모 머지는 사용자 승인 후. (error entrenchment 방지)
- 한 페이지 = 한 개념. 개념 경계가 모호하면 쪼개거나 사용자에게 물어라.
- entity는 event를 **삭제하지 않는다. 참조한다.** 원본 session/lesson은 그대로 둔다.
