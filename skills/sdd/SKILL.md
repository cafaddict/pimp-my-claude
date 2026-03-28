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

`spec-writer` 에이전트 호출 → `.specs/<spec-id>.md` 생성 (status: `draft`).
- 입력: $ARGUMENTS + 프로젝트 컨텍스트 (현재 디렉토리, 주요 파일/모듈)
- spec-id: kebab-case만 허용 (`[a-z0-9]+(-[a-z0-9]+)*`). `..`, `/`, 공백 금지.
- `.specs/` 디렉토리 없으면 생성.

---

### Phase 2: REVIEW

스펙을 사용자에게 제시. 승인 → `approved`로 Phase 3 / 수정 요청 → spec-writer 재호출 / 거부 → 종료.
Open Questions 있으면 사용자 확인 후 반영.

---

### Phase 3: BUILD LOOP

구현 모드 선택 (사용자에게 질문):
1. **Direct** (기본): spec → implementer
2. **TDD**: Test Criteria → test-writer(RED) → implementer(GREEN)
3. **Parallel**: 복수 모듈이면 병렬 implementer (worktree 격리)

최대 반복: **기본 3회** (조절 가능). **Lightweight**: Behaviors + Acceptance Criteria 합계 3개 이하면 single-pass.

#### 3a: IMPLEMENT

`implementer` 에이전트 호출 (매 iteration fresh agent):
- **1차**: 스펙 파일 경로 전달. stub/placeholder/TODO 금지.
- **2차+**: 스펙 + 최신 `.verified-N.md`의 Feedback 섹션 + 미해결 항목 전달.
- implementer는 **스펙 문서만** 받는다 (요구사항 원문 X).

**TDD 모드**: test-writer에 Test Criteria 전달(RED) → 실패 확인 → implementer에 테스트+스펙 전달(GREEN) → verify 루프 동일. test-writer는 1차만, 2차+는 implementer만 재실행.

Parallel 모드: 모듈별 implementer를 `isolation: worktree`로 병렬 실행.

#### 3b: VERIFY

`spec-verifier` 에이전트 호출 → `.specs/<spec-id>.verified-<N>.md`에 결과 저장.
입력: 스펙 파일 + 구현 위치 + iteration 번호. 회의적으로 판단.

#### 3c: DECISION

- **PASS** → Phase 4
- **PARTIAL/FAIL** (max 미도달): 최신 피드백 요약 → 3a (fresh agent)
- **PARTIAL/FAIL** (max 도달): 사용자 선택 — (1) partial 유지 (2) revert (3) +N회 연장
- **스펙 문제 발견**: 루프 탈출 → 사용자 에스컬레이션 → spec version++ → 루프 재진입

---

### Phase 4: REPORT

최종 보고 형식: spec ID/version, status, iterations N/max, 최종 verdict, 변경 파일 목록, iteration 히스토리 표 (`# | Verdict | 주요 피드백`). 히스토리는 `.verified-*.md`에서 구성.

**Vault 통합** (note 스킬):
- 최종 스펙 → `vault/projects/<project>/specs/<spec-id>.md`에 보관
- iteration > 1이면 재작업 원인을 `vault/lessons/`에 기록
- 사용자가 FAIL 오버라이드하면 `vault/areas/harness-engineering/evaluator-calibration.md`에 기록
- 주요 설계 결정 → vault decisions/에 기록

---

### 스펙 진화

스펙 변경 필요 시: 보고 → 사용자 승인 → spec-writer 재호출(version++) → 이전 버전 `.specs/archive/`로 이동 → 루프 재진입.
카운터 정책: 변경 시 iteration 0으로 리셋. 총 스펙 변경 최대 2회. 3회째 → "요구사항 재정의 필요" 경고 후 종료.

---

### 주의

- 스펙이 계약 — implementer에게 요구사항 원문 직접 전달 금지
- spec-verifier 판단 존중 (skeptical 튜닝이 핵심)
- 피드백은 **최신 report + 미해결 항목 요약**만 전달 (누적 X)
