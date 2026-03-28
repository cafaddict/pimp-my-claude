---
name: feature-team
description: |
  병렬 피처 개발. 여러 피처를 동시에 구현할 때 서브에이전트를 worktree 격리로 병렬 실행.
  Use when: 여러 피처를 동시에 구현, 대규모 리팩토링을 모듈별 분할.
argument-hint: "[피처1, 피처2, ...]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
effort: high
---

## 병렬 피처 개발

서브에이전트(implementer)를 worktree 격리로 병렬 실행한다.
Agent Teams가 아닌 Subagent 패턴 — 독립 작업이므로 팀원 간 통신 불필요.

### 프로세스

#### 1. 인터페이스 확정
먼저 공유 인터페이스/타입을 확정하라.
피처 간 공유되는 API, 타입, 설정 등을 정의하고 파일로 작성.

#### 2. 작업 분해
$ARGUMENTS를 파싱하여 각 피처를 독립적인 작업으로 분해.
각 피처의:
- 담당 파일/모듈 범위
- 의존하는 인터페이스
- 완료 기준

#### 3. 병렬 실행
각 피처에 대해 `implementer` 에이전트를 **병렬로** 실행하라.
반드시 `isolation: worktree`로 실행.

```
피처마다 Agent 도구를 병렬로 호출:
- subagent_type: implementer (또는 general-purpose + isolation: worktree)
- prompt: "피처 X를 구현하라. 범위: src/X/ only. 인터페이스: [공유 인터페이스 내용]"
```

#### 4. 결과 통합
모든 서브에이전트 완료 후:
- 각 worktree의 변경사항 확인
- 인터페이스 충돌 여부 체크
- 통합 테스트 실행

#### 5. 보고
사용자에게 각 피처의 결과와 머지 순서를 제안.

### 주의
- 공유 파일을 여러 에이전트에 할당하지 마라 (충돌)
- 인터페이스 미확정 상태로 병렬 실행 금지
- 10개 이상 에이전트 동시 실행 금지
