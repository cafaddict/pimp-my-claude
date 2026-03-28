---
name: sdd
description: |
  Spec-Driven Development. 요구사항을 스펙으로 형식화 → 승인 → 구현 ↔ 검증 피드백 루프.
  Generator-Evaluator 패턴으로 품질 수렴.
  Use when: "스펙 먼저", "spec-driven", "sdd" 요청 시.
argument-hint: "[요구사항 설명]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
effort: high
---

## Spec-Driven Development (Generator-Evaluator Loop)

스펙이 계약이다. implementer는 스펙만 보고 구현하고, spec-verifier가 회의적으로 검증한다.
검증 실패 시 피드백을 주고 다시 구현 — 품질이 수렴할 때까지 반복.

---

### Phase 1: SPEC

`spec-writer` 에이전트를 호출하여 스펙 생성:

```
요구사항: $ARGUMENTS
프로젝트 컨텍스트: [현재 디렉토리, 주요 파일/모듈]

이 요구사항을 구조화된 스펙 문서로 형식화하라.
기존 코드베이스의 인터페이스와 패턴을 반영하라.
```

**spec-id 검증**: kebab-case만 허용 (`[a-z0-9]+(-[a-z0-9]+)*`). `..`, `/`, 공백 포함 시 거부.

결과를 `.specs/<spec-id>.md`에 저장 (status: `draft`).

`.specs/` 디렉토리가 없으면 생성.

---

### Phase 2: REVIEW

스펙을 사용자에게 제시하고 승인을 요청:

- **승인**: status를 `approved`로 업데이트 → Phase 3
- **수정 요청**: 피드백으로 spec-writer 재호출 → 스펙 업데이트 → 다시 제시
- **거부**: 종료

**Open Questions 항목이 있으면** 사용자에게 확인 후 스펙에 반영.

---

### Phase 3: BUILD LOOP

사용자에게 구현 모드를 물어본다:

1. **Direct** (기본): spec → implementer
2. **TDD**: spec의 Test Criteria → test-writer(RED) → implementer(GREEN)
3. **Parallel**: 복수 모듈이면 병렬 implementer (worktree 격리)

최대 반복 횟수: **기본 3회** (사용자 조절 가능).

**Lightweight 모드**: 스펙의 Behaviors + Acceptance Criteria가 합계 3개 이하이면, 루프 없이 single-pass (1회 implement + 1회 verify)로 실행. 사용자에게 "lightweight 모드로 실행합니다" 알림.

#### 3a: IMPLEMENT

`implementer` 에이전트를 호출:

**1차 iteration:**
```
스펙 파일: .specs/<spec-id>.md
이 스펙을 구현하라. 스펙의 Interfaces, Behaviors, Constraints를 모두 충족해야 한다.
stub, placeholder, TODO를 남기지 마라.
```

**2차+ iteration:**
```
스펙 파일: .specs/<spec-id>.md
이전 검증 피드백: [최신 verification report의 "Feedback for Next Iteration" 섹션]
미해결 항목: [PARTIAL/FAIL인 항목 목록]

피드백에 따라 구현을 수정하라.
```

- implementer는 **스펙 문서만** 받는다 (원래 요구사항 원문 X)
- 매 iteration마다 **fresh agent** (자동 context reset)
- **TDD 모드 상세:**
  1. spec의 Test Criteria를 test-writer에 전달 → 실패 테스트 작성 (RED)
  2. 실패 확인
  3. implementer에 테스트 파일 + 스펙 전달 → 최소 구현 (GREEN)
  4. spec-verifier로 검증 (verify 루프는 동일하게 적용)
  - test-writer는 1차 iteration에서만 실행. 2차+ iteration에서는 기존 테스트 유지, implementer만 재실행.
- Parallel 모드: 모듈별 implementer를 `isolation: worktree`로 병렬 실행

#### 3b: VERIFY

`spec-verifier` 에이전트를 호출:

```
스펙 파일: .specs/<spec-id>.md
구현 위치: [변경된 파일/디렉토리]
Iteration: N

스펙 대비 구현을 검증하라. 회의적으로 판단하라.
```

결과를 `.specs/<spec-id>.verified-<N>.md`에 저장 (N=iteration 번호).

#### 3c: DECISION

검증 결과의 verdict에 따라:

- **PASS**: 루프 탈출 → Phase 4
- **PARTIAL/FAIL**:
  - max iteration 미도달: 최신 `.verified-N.md`에서 피드백 요약 생성 → 3a로 (fresh agent)
  - max iteration 도달 (PARTIAL/FAIL):
    사용자에게 선택지 제시:
    1. 현재 partial 구현 유지 (수동 마무리)
    2. pre-SDD 상태로 revert
    3. max iteration 추가 연장 (+N회)
- **스펙 문제 발견** (verifier가 "스펙 자체가 모호/불완전" 지적):
  - 루프 탈출 → 사용자에게 에스컬레이션
  - 사용자 확인 후 spec version++ → 루프 재진입

---

### Phase 4: REPORT

최종 결과를 보고:

```
## SDD 결과: <spec-id>

### 스펙
- ID: <spec-id> v<version>
- Status: verified | partial | max-iterations-reached

### Build Loop
- Iterations: N/max
- 최종 verdict: PASS/PARTIAL/FAIL

### 변경 파일
- <파일 목록>

### Iteration 히스토리
| # | Verdict | 주요 피드백 |
|---|---------|------------|
| 1 | FAIL | ... |
| 2 | PARTIAL | ... |
| 3 | PASS | — |
```

Iteration 히스토리는 `.verified-1.md`, `.verified-2.md` 등에서 읽어 구성.

vault에 기록 (note 스킬):
- `.specs/<id>.md`의 위치를 vault reference로 기록
- 주요 설계 결정이 있었으면 vault decisions/에 기록

**Vault 통합:**
- **Spec 아카이브**: 최종 verified 스펙을 `vault/projects/<project>/specs/<spec-id>.md`에 보관 → /recall로 검색 가능
- **실패 패턴 기록**: iteration > 1이면, 재작업 원인 카테고리(스펙 모호, 구현 누락, 엣지 케이스 등)를 `vault/lessons/`에 기록 (note 스킬)
- **Evaluator 캘리브레이션**: 사용자가 verifier FAIL을 오버라이드하면, `vault/areas/harness-engineering/evaluator-calibration.md`에 false positive로 기록

---

### 스펙 진화

구현 중 스펙 변경이 필요한 경우:
1. implementer 또는 verifier가 스펙 문제를 보고
2. 루프 탈출 → 사용자에게 에스컬레이션
3. 사용자 승인 후 spec-writer 재호출 → version++
4. 이전 버전은 `.specs/archive/`로 이동
5. 새 버전으로 루프 재진입

**카운터 정책**: 스펙 변경 시 iteration 카운터는 0으로 리셋. 단, 총 스펙 변경은 최대 2회까지 허용. 3회째 변경 요청 시 "요구사항 재정의 필요" 경고 후 종료.

---

### 주의

- implementer에게 요구사항 원문을 직접 주지 마라 (스펙이 계약)
- spec-verifier의 판단을 무시하지 마라 (skeptical 튜닝이 핵심)
- 피드백은 누적이 아닌 **최신 report + 미해결 항목 요약**만 전달
- 반복이 품질을 보장하지 않는다 — max iteration 도달 시 현황 보고 후 사용자 판단
