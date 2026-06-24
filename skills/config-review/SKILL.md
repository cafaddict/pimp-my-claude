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

기본은 **읽기 전용 리포트**다. `--apply`가 있을 때만 변경하며, **삭제는 항상 사용자 승인**을 받는다.

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

### Phase 4 — APPLY (산출 2: `--apply` 일 때만)
1. 제안 목록을 표로 출력 → 사용자 "전부 / N번만 / 취소" 선택 (`/vault-promote`와 동일 UX).
2. **삭제·이동은 승인된 것만** Edit/Write. 삭제 후 "Claude 행동이 바뀌는지 관찰하라"고 안내.
3. **hook 승격 후보는 직접 만들지 마라** — `/harness`로 인계(harness가 build-loop·배포·README 동기화 담당). 역할 침범 금지.
4. **~/.claude/ 의 hook/skill을 수정하면 pimp-my-claude 레포에도 반영 + README 업데이트** (소스 = 레포).

### Phase 5 — 마커 갱신
점검 완료 시(리포트만 냈어도) staleness 넛지용 마커를 갱신:
```bash
date +%s > "${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}/.config-review-stamp"
```
이로써 vault-briefing의 분기 넛지 타이머가 리셋된다.

### 주의
- 기본은 제안만. 파괴적 변경(삭제)은 승인 게이트 필수.
- "분기 점검"은 백스톱일 뿐 — **이벤트 기반(피처 종료/버그 발생 시)이 1차**다.
- 미사용 단정 금지(로그 부재 시 확인 요망으로).
