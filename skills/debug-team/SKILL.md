---
name: debug-team
description: |
  경쟁적 가설 기반 디버깅 팀. Agent Teams로 여러 조사관이 서로 반증하며 원인 추적.
  Use when: 원인 불명 버그, 간헐적 에러, "team debug" 요청 시.
argument-hint: "[버그 설명]"
allowed-tools: Read, Grep, Glob, Bash
effort: high
---

## 경쟁적 가설 디버깅 팀

Agent Teams를 생성하여 3명의 조사관이 각각 다른 가설을 검증하고 서로 반박한다.

### 팀 구성 프롬프트

먼저 버그 증상을 파악한 후, 3개의 가설을 생성하라.
그 다음 Agent Team을 생성:

```
Bug: $ARGUMENTS

Generate 3 competing hypotheses for this bug.

Create an agent team — one investigator per hypothesis:

1. **Investigator A**: Hypothesis — [가설 1]
   Find evidence FOR or AGAINST. Check relevant logs, code paths.

2. **Investigator B**: Hypothesis — [가설 2]
   Find evidence FOR or AGAINST. Check relevant logs, code paths.

3. **Investigator C**: Hypothesis — [가설 3]
   Find evidence FOR or AGAINST. Check relevant logs, code paths.

Instructions:
- Share findings with each other directly
- Actively try to DISPROVE each other's hypotheses
- If your own hypothesis lacks evidence, say so honestly
- Consensus through debate, not guessing

Lead: synthesize the surviving hypothesis with strongest evidence.
```

### Vault 기록
근본 원인 합의 도출 후, 오케스트레이터가 /vault-note 스킬로 vault `lessons/`에 기록하라.
기록 대상: surviving hypothesis, 검증 방법, 교훈.
조사관 agent가 직접 vault에 쓰지 않는다 — 오케스트레이터가 종합 후 기록.

### 주의
- 조사관에게 Write/Edit 권한을 주지 않는다 (원인 확인 전 수정 금지)
- 단순 버그는 `/debugit` 스킬이 더 효율적 (팀은 원인 불명 시)
