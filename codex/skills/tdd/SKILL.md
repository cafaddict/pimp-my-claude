---
name: tdd
description: "실패 테스트 작성과 구현을 별도 Codex subagent에 맡겨 RED→GREEN→REFACTOR를 진행한다. TDD, 테스트 먼저 요청에 사용한다."
---

공개 인터페이스, 기대 동작과 기존 테스트 실행법을 먼저 확인한다. 구현자가 쓸 해결책은
test-writer에게 전달하지 않는다. 기존 변경이 있으면 시작 시점의 범위를 기록한다.

1. **RED**: 새 `test-writer` subagent에 요구사항·공개 인터페이스·테스트 관례만 전달한다.
   가능한 경우 부모 대화를 상속하지 않는 새 context로 실행한다. target 구현을 읽거나
   production 파일을 바꾸지 않게 한다. 테스트를 실행해 기능 부재로 실패하는지 확인한다.
   import 오류나 환경 실패는 RED 증거로 쓰지 않는다. 테스트가 이미 통과하면 이유를 조사한다.
2. **GREEN**: 확인한 실패 테스트와 요구사항을 새 `implementer`에 전달한다.
   유효한 테스트를 약하게 바꾸지 않고 최소 구현으로 통과시킨다.
3. **REFACTOR**: 필요한 정리만 수행하고 같은 테스트와 관련 기존 검사를 다시 실행한다.
4. 실패·통과 명령과 결과, 변경 파일, 확인하지 못한 범위를 보고한다.

여러 기능은 서로 독립적일 때만 기능별 RED→GREEN을 병렬로 실행한다. agent 수 제한을
지키고 서로 겹치지 않는 파일 범위를 준다. 같은 파일을 바꾸면 순서대로 실행한다.
worktree가 필요하면 `$feature-team`의 명시적 checkout 절차를 따른다.

custom agent가 없으면 같은 지시로 일반 subagent를 쓴다. 새 context나 subagent 도구가
제공되지 않으면 제한을 알리고 메인 agent가 RED→GREEN을 순서대로 진행한다.
그 경우 독립 context에서 테스트를 작성했다고 설명하지 않는다.
