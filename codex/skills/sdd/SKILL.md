---
name: sdd
description: "요구사항을 스펙으로 정리한 뒤 구현·검증 루프를 실행한다. sdd, 스펙 먼저, spec-driven, reverse spec 요청에 사용한다."
---

스펙은 `.specs/<spec-id>.md`에 둔다. ID는 소문자·숫자·하이픈으로 만들고 경로 구분자나
`..`를 허용하지 않는다. `--reverse <대상> [--scope <초점>]`가 있으면 아래 Reverse 절차를 따른다.
그 외에는 사용자가 준 요구사항을 Forward 절차로 처리한다.

### Forward

1. `spec-writer`에 요구사항과 관련 코드·인터페이스를 전달한다. 반환한 문서를 메인 agent가
   `status: draft`로 저장한다. Behaviors, Constraints, Acceptance Criteria, Test Criteria와
   Open Questions를 포함하고, 구현 방법보다 관찰 가능한 동작을 명확히 한다.
2. 스펙을 사용자가 검토할 수 있게 제시한다. 이미 승인된 스펙과 범위면 이어서 진행한다.
   미결정 사항이나 새 동작은 확인하고, 승인된 스펙만 `status: approved`로 구현한다.
3. 요청한 모드가 있으면 따른다. 기본은 Direct이며, 테스트 우선 요청은 `$tdd`, 독립 모듈
   병렬 구현 요청은 `$feature-team` 절차를 쓴다. 병렬 작업에도 같은 스펙과 파일 범위를 준다.
4. 매 iteration 새 `implementer`에 스펙과 코드 위치를 준다. 부모 대화를 상속하지 않는
   context를 지원하면 사용하고, 요구사항 원문과 이전 해결책을 추가하지 않는다.
   2회째부터는 최신 검증 report와 미해결 항목만 추가한다.
5. 별도 `spec-verifier`에 스펙·구현 경로·iteration을 전달한다. 반환한 근거와 검증 결과를
   메인 agent가 `.specs/<spec-id>.verified-<N>.md`에 저장한다.
6. PASS면 완료한다. PARTIAL/FAIL이면 최신 피드백으로 반복하며 기본 최대 3회로 제한한다.
   한도에 도달하면 남은 문제와 현재 변경을 제시하고 유지·추가 작업 등 사용자 선택을 받는다.
   사용자 변경을 자동으로 revert하지 않는다.

스펙을 바꿔야 하면 루프를 멈추고 변경안을 제시한다. 승인 후 이전 스펙을 `.specs/archive/`에
보존하고 version을 올린다. 새 version의 iteration은 1부터 시작하며 version을 보고서에 적는다.
기본 스펙 변경 한도는 2회다. 더 필요하면 원인과 요구사항을 다시 확인한다.

### Reverse

1. `spec-writer`에 `[REVERSE MODE]`, 대상 경로와 scope를 전달한다. 관찰한 동작과 추정한
   의도를 구분하고, `source: reverse`, `target`과 Open Questions가 있는 draft를 저장한다.
2. 추정한 의도와 빠진 업무 맥락을 사용자에게 제시한다. 이미 지정한 후속 작업이 있으면
   따르고, 없으면 문서화만 / 테스트 갭 검증 / baseline 이후 Forward 중 선택을 받는다.
3. 검증은 `spec-verifier`가 행위별 테스트와 에러 경로의 빈틈을 확인하고
   `.specs/<spec-id>.verified-gap.md`로 반환한다. 코드와 스펙이 같다는 이유만으로 PASS 처리하지 않는다.
   Forward로 이어가면 baseline을 보존하고 추가 요구사항을 새 스펙에 반영한다.

### 역할과 보고

custom agent가 없으면 같은 역할을 일반 subagent에 전달한다. subagent 도구나 새 context가
없으면 한계를 알리고 단계를 순서대로 수행한다. 독립 검증을 했다고 꾸미지 않는다.
최종 보고에는 spec ID/version/status, iteration별 verdict, 검사 결과와 남은 문제를 포함한다.
재사용할 스펙·결정·교훈은 vault 저장을 제안하며, 사용자 요청·승인 후 메인 agent가
`$vault-note`로 기록한다. 하위 agent는 vault에 직접 쓰지 않는다.
