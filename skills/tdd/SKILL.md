---
name: tdd
description: |
  TDD 사이클. test-writer가 실패 테스트 작성 → implementer가 구현 → 테스트 통과 확인.
  여러 기능을 동시에 TDD로 개발 가능 (기능 간 병렬, 기능 내 순차).
  Use when: "TDD", "테스트 먼저", test-driven 개발 요청 시.
argument-hint: "[구현할 기능들 설명]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
effort: high
---

## TDD 사이클 (Red → Green → Refactor)

서브에이전트로 test-writer와 implementer를 실행.
컨텍스트 격리가 핵심 — test-writer는 구현을 모르는 상태에서 테스트를 작성해야 진짜 TDD.

### 단일 기능 TDD

#### Phase 1: RED (실패 테스트 작성)

`test-writer` 에이전트를 호출:
```
기능 요구사항: $ARGUMENTS

이 요구사항만 보고 실패하는 테스트를 작성하라.
구현 파일은 읽지 마라.
테스트를 실행하여 실패하는 것을 확인하라.
```

**실패 확인 전에 Phase 2로 넘어가지 마라.**

#### Phase 2: GREEN (최소 구현)

테스트 파일 경로를 확인한 후, `implementer` 에이전트를 호출:
```
테스트 파일 [경로]를 읽고, 이 테스트를 통과하는 최소한의 구현을 작성하라.
과도한 기능 추가 금지. 테스트를 통과하는 것만 목표.
```

**통과 확인 전에 Phase 3으로 넘어가지 마라.**

#### Phase 3: REFACTOR (선택)

메인 세션에서 리팩토링 (테스트 통과 유지).

---

### 여러 기능 병렬 TDD

$ARGUMENTS에 여러 기능이 있으면, **기능 간은 병렬, 기능 내는 순차**로 실행.

```
기능 A: test-writer-A → (실패 확인) → implementer-A  ─┐
기능 B: test-writer-B → (실패 확인) → implementer-B  ─┼─ 병렬
기능 C: test-writer-C → (실패 확인) → implementer-C  ─┘
```

#### 프로세스

1. $ARGUMENTS를 독립적인 기능 단위로 분해
2. 각 기능에 파일/모듈 범위를 할당 (충돌 방지)
3. **Phase 1 병렬**: 모든 기능의 test-writer를 동시에 실행
4. 각 test-writer 완료 시 실패 확인
5. **Phase 2 병렬**: 실패 확인된 기능의 implementer를 동시에 실행 (worktree 격리)
6. 모든 implementer 완료 후 전체 테스트 실행

#### 주의 (병렬 시)
- 각 기능의 테스트 파일과 구현 파일이 겹치지 않아야 함
- implementer는 `isolation: worktree`로 실행
- 공유 인터페이스가 있으면 먼저 확정 후 병렬 실행

---

### 보고

사이클 완료 후 보고:
- 기능별: 작성된 테스트 / 구현 변경 / 테스트 결과
- 전체 테스트 스위트 통과 여부

### 주의
- test-writer에게 구현 파일을 보여주지 마라 (TDD 원칙 위반)
- implementer에게 요구사항 스펙을 직접 주지 마라 (테스트가 스펙)
- 실패/통과 확인 없이 다음 Phase로 넘어가지 마라
