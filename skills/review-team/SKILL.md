---
name: review-team
description: |
  경쟁적 멀티 관점 코드 리뷰 팀. Agent Teams로 3명이 서로 반박하며 리뷰.
  Use when: "팀 리뷰", "thorough review", 중요한 PR 리뷰가 필요할 때.
argument-hint: "[PR번호 또는 빈칸]"
allowed-tools: Read, Grep, Glob, Bash
effort: high
---

## 경쟁적 코드 리뷰 팀

Agent Teams를 생성하여 3명의 리뷰어가 서로 반박하며 리뷰한다.

### 팀 구성 프롬프트

다음과 같이 Agent Team을 생성하라:

```
Create an agent team to review $ARGUMENTS (또는 현재 git diff).

Spawn 3 competitive reviewers:

1. **Security Reviewer**: 보안 관점에서 검토. 인젝션, 인증 우회, 시크릿 노출, 입력 검증.
   Read-only tools only.

2. **Performance Reviewer**: 성능 관점에서 검토. 알고리즘 복잡도, N+1 쿼리, 메모리, 블로킹.
   Read-only tools only.

3. **Correctness Reviewer**: 정확성 관점에서 검토. 로직 오류, 엣지 케이스, 에러 핸들링, 테스트 커버리지.
   Read-only tools only.

Instructions:
- Each reviewer: message the others directly to challenge findings
- If you disagree with another reviewer's assessment, say so with evidence
- After review, each delivers findings ranked Critical/Warning/Suggestion
- Lead synthesizes all findings into a final report
```

### Vault 기록
리뷰 종합 후, 반복적으로 발견되는 패턴(보안 취약점 패턴, 성능 안티패턴 등)이 있으면
오케스트레이터가 /note 스킬로 vault `lessons/`에 기록하라.
리뷰어 agent가 직접 vault에 쓰지 않는다 — 결과를 종합한 뒤 오케스트레이터가 기록.

### 주의
- 리뷰어에게 Write/Edit 권한을 주지 않는다
- 단순 리뷰는 `/review` 스킬이 더 효율적 (팀은 중요 PR용)
