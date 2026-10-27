---
name: feature-team
description: "독립 피처를 Codex subagent에 나눠 구현하고 통합한다. 여러 피처 병렬 개발이나 모듈별 작업 분할 요청에 사용한다."
---

먼저 공유 인터페이스·타입·설정과 완료 기준을 정한다. 공유 파일은 메인 agent가 담당하고
각 피처의 쓰기 범위는 겹치지 않게 나눈다. 의존하는 작업은 순서대로 실행한다.

1. `git status`로 기존 변경과 untracked 파일을 확인한다. 피처별 담당 파일, 인터페이스,
   테스트 명령과 완료 기준을 명확히 한다.
2. clean checkout이고 worktree 분리가 도움이 되면 메인 agent가
   `git worktree add --detach <임시경로> HEAD`로 피처별 checkout을 만든다.
   각 agent에 실제 경로를 전달하고 모든 명령을 그 경로에서 실행하게 한다.
   Git 저장소가 아니거나 기존 변경이 작업에 필요하면 같은 checkout에서 파일 범위를 나눈다.
   안전하게 나눌 수 없으면 순서대로 구현한다. `isolation` 옵션이 자동 checkout을 만든다고 가정하지 않는다.
3. 피처마다 `implementer` subagent를 실행한다. 현재 agent 수 한도를 지키고, 공유 인터페이스
   변경이 필요하면 작업을 멈춰 메인 agent에 보고하도록 지시한다.
4. 모든 결과와 검사를 확인한다. worktree를 썼다면 tracked diff와 새 파일을 모두 포함한
   피처별 patch를 만들고 `git apply --check` 후 원래 checkout에 순서대로 반영한다.
   충돌은 변경을 버리지 말고 해결한다. 기존 사용자 변경이 생겼으면 다시 대조한다.
5. 통합 테스트를 실행하고 피처별 결과, 통합 변경과 남은 제한을 보고한다.
   commit·merge·push는 사용자 요청이 있을 때만 한다.

custom agent가 없으면 일반 subagent에 구현 역할을 전달한다. subagent 도구가 없으면 같은
범위와 검사를 유지해 순서대로 작업한다. 생성한 임시 worktree는 patch 반영과 새 파일 보존을
확인한 뒤 정리한다. 자동 정리에 `--force`를 쓰지 말고, 제거하지 못한 경로는 보고한다.
