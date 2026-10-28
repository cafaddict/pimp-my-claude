---
name: config-review
description: |
  Claude Code harness(CLAUDE.md, .claude/rules, skills, hooks, agents)의 staleness·bloat·중복·끊긴 참조를 감사하고 prune/dedup/reroute를 제안한다. /vault-promote의 역방향(추가가 아닌 정리).
  사용 시점:
  - 피처/작업 완료 직후 (이벤트 기반 1차 트리거)
  - 세션 시작 브리핑에 staleness 넛지가 떴을 때 (분기 백스톱)
  - "설정 점검", "config 정리" 요청 시
argument-hint: "[--project <name>] [--apply]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
effort: high
---

## Config Review — harness 감사·정리

설정은 코드처럼 다뤄야 한다 — 잘못될 때 리뷰하고, 정기적으로 prune하고, 변경 후 행동이 실제로 바뀌는지 확인한다. **bloat된 CLAUDE.md는 Claude가 규칙을 무시하게 만든다.**

> [!tip] `/vault-promote`와의 관계 (living-config의 들숨/날숨)
> `/vault-promote` = 지식을 규칙으로 **들인다**(lessons → rules, 추가). `/config-review` = 낡은 규칙을 **정리한다**(prune/dedup/reroute, 제거). 둘이 한 사이클을 이룬다.

기본은 **읽기 전용 리포트**다. 파일을 하나도 쓰지 않는다(마커 포함). `--apply`가 있을 때만 변경하며, **삭제는 항상 사용자 승인**을 받는다.

### Phase 0 — SCOPE
점검 대상 결정:
- 전역: `~/.claude/CLAUDE.md`, `~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/hooks/`, `~/.claude/agents/`, `~/.claude/AGENTS.md`
- 프로젝트: 현재 작업 디렉토리의 `./CLAUDE.md`, `./.claude/`
- `--project <name>` 지정 시 해당 프로젝트로 스코프 한정.

### Phase 1 — MEASURE (정량, Bash, 비-LLM)
스크립트로 객관 신호부터 수집:
- **줄 수**: 각 CLAUDE.md/rule 파일 `wc -l`. 200줄 권장 상한, 300줄 경고.
- **stale 날짜**: per-turn 문서에서 30일+ 오래된 날짜/섹션 grep.
- **끊긴 참조**: CLAUDE.md의 `@path` import와 wikilink 대상을 Glob으로 실존 검증 → 깨진 참조 목록.
- **인벤토리**: skills/·hooks/·agents/ 목록(이름·줄 수·마지막 수정일 `stat`).

### Phase 2 — ANALYZE (LLM 판단)
정량 신호 위에 의미 판단을 얹는다:
- **Dedup**: CLAUDE.md ↔ rules ↔ skills 간 같은 문구·절차 중복 → 한 곳만 남김.
- **Stale/obsolete**: 신모델이 기본으로 하는 것(예: "think step by step" 잔재), 죽은 도구·경로 참조.
- **Misroute**: 절차형(step-by-step)이 CLAUDE.md/rule에 박힘 → **skill로 이동** 제안. 매번 예외 없이 일어나야 하는 규칙 → **hook 승격** 제안.
- **Conflict**: CLAUDE.md / rules / skills / global memory 간 모순 instruction.
- **Unused**: 최근 미사용으로 보이는 skill/agent 후보. (사용 로그가 없으면 단정 말고 "확인 요망"으로만 표시.)

판정 휴리스틱:
- "이 줄을 지우면 Claude가 실수하게 되는가?" → 아니면 cut 후보.
- "매번 예외 없이?" → hook. "가끔만?" → skill. "항상 advisory?" → rule.

#### 프롬프트 패턴 (그 파일을 읽는 모델 기준)
Claude 설정만 깊게 볼 때는 내장 `/doctor prompt-audit` 이 같은 기준을 쓴다.
대상 모델은 파일을 읽는 모델이다. `model:` 을 고정한 skill·agent 는 그 모델 기준으로 본다.
- **압박 표현**: 이유 없는 `반드시`·`절대`·CRITICAL·굵은 경고, 반대로 진짜 요구에 붙은 "가능하면". 지금 모델은 지시를 글자 그대로 따라 과하게 반응한다 → 평범한 말과 이유로 바꾼다.
- **모델이 알아서 하는 일**: "단계별로 생각하라", 요청을 내부 구조로 바꾸라는 지시, 판단 작업에 강제한 단계 순서나 개수(가설 최소 N개) → 목표와 지켜야 할 제약만 남긴다.
- **화석**: 옛 모델용 우회, 컨텍스트 % 같은 수치 규칙, 고정된 옛 모델 ID, 날짜·사건이 붙은 이력, "이제는 ~" 처럼 이전 버전과 비교하는 문장 → 지금 규칙만 쓴다.
- **실물과 다른 내용**: 설치되지 않은 플러그인·MCP 를 나열한 산문, 없는 경로·명령, 도구가 읽지 않는 frontmatter 필드(Claude rule 은 `paths` 만 읽는다. `globs` 는 무시돼 매 세션 로드된다).
- **소비자 없는 지시**: 아무도 읽지 않는 출력 섹션, 스스로 "강제되지 않는다"고 밝힌 규칙 → hook·도구 제한으로 옮기거나 지운다.

남기는 것: 작성자만 아는 맥락과 제약의 이유, 되돌리기 어려운 작업의 정확한 절차, 실제로 재발한 실패를 막는 금지, description 의 트리거 문구, 내용이 일치하는 중복. 길이만으로는 지우지 않는다.
충돌은 두 위치를 인용하고 git 이력으로 어느 쪽이 최신인지 정한다. 이력으로 정할 수 없으면 고치지 말고 사용자가 정할 질문으로 보고한다. 프로젝트 파일을 근거로 전역 파일을 고치지 않는다.

### Phase 3 — REPORT (산출 1: 읽기 전용)
심각도 정렬(BROKEN REF > CONFLICT > DUPLICATE > BLOAT > STALE)로 항목별 리포트:
```
[CLAUDE.md:30] DUPLICATE — 컨텍스트 위생 규칙이 rules/context-hygiene.md와 중복
  → CLAUDE.md에서 삭제, rule 유지            | 절감 ~4줄/턴
[rules/foo.md:1-25] MISROUTE — 절차형, hook 후보(deterministic)
  → /harness로 hook 승격 검토
[CLAUDE.md] BROKEN REF — @docs/git.md 파일 없음
```
파일별 before/after 줄 수 델타를 함께 표시.
STALE·CONFLICT 항목에는 인용·패턴·이유·확신도(High/Medium/Low)·조치(remove/rewrite/flag)를 붙인다.
변경안은 diff 로 보이고, Low 와 flag 는 diff 에 넣지 않는다.

### Phase 4 — APPLY (산출 2: `--apply` 일 때만)
1. 제안 목록을 표로 출력 → 사용자 "전부 / N번만 / 취소" 선택 (`/vault-promote`와 동일 UX).
2. **삭제·이동은 승인된 것만** Edit/Write. 삭제 후 "Claude 행동이 바뀌는지 관찰하라"고 안내.
3. **hook 승격 후보는 직접 만들지 마라** — `/harness`로 인계(harness가 build-loop·배포·README 동기화 담당). 역할 침범 금지.
4. **~/.claude/ 의 hook/skill을 수정하면 pimp-my-claude 레포에도 반영 + README 업데이트** (소스 = 레포).

### Phase 5 — 마커 갱신 (`--apply`를 실행했거나 사용자가 승인했을 때만)
리포트만 낸 경우에는 쓰지 않는다. 리포트 끝에 "점검 완료로 표시할까요?"라고 묻고, 사용자가 승인하거나
`--apply`로 변경을 적용했을 때만 vault **밖**의 마커를 갱신한다:
```bash
date +%s > "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.config-review-stamp"
```
이로써 vault-briefing의 분기 넛지 타이머가 리셋된다. 예전 위치(vault 루트의 `.config-review-stamp`)는
vault-briefing이 새 마커가 없을 때 읽기만 하며, 이 skill은 그 파일을 고치거나 지우지 않는다.

### 주의
- 기본은 제안만. 파괴적 변경(삭제)은 승인 게이트 필수.
- "분기 점검"은 백스톱일 뿐 — **이벤트 기반(피처 종료/버그 발생 시)이 1차**다.
- 미사용 단정 금지(로그 부재 시 확인 요망으로).
