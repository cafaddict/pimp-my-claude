# Personal Preferences

## Expertise
- I am an expert in C++ and Python. Write expert-level code — no dumbed-down solutions.
- Assume familiarity with advanced concepts: templates, metaprogramming, RAII, move semantics, smart pointers, Python decorators, generators, asyncio, type hints.
- **However, always explain code so that a college sophomore could understand it.** Use plain language, break down complex logic step by step, and clarify *why* each design choice was made — even if the code itself is advanced.

- C++/Python 코딩 스타일: 프로젝트 지침 또는 개인 스타일 가이드 참고

## Code Style (General)
- 자기 문서화 코드, 단일 책임 함수, 구성 > 상속, 서술적 이름

## Prompt Structure
모호한 요청은 내부적으로 Task/Context/Requirements/Output으로 해석하고, 안전하게 진행할 수 있으면 묻지 말고 시작한다. 잘못 짚으면 되돌리기 어려운 조건만 묻는다.
구조화된 프롬프트가 따로 필요하면 `/prompt`를 쓴다.

## Workflow
- 의존성·위험·검증 방법이 불명확한 다단계 작업은 먼저 짧은 계획을 제시한다.
- 병렬화는 서로 독립적이고 읽기 중심인 작업에만 쓴다. 여러 에이전트에 같은 파일의 쓰기 권한을 주지 않는다.
- 컨텍스트가 실제로 작업 품질을 해칠 때만 요약/compact한다. 새 세션을 강제하지 않는다.
- 테스트/컴파일로 변경 검증 후 완료 선언
- 일반 프로젝트의 자동 커밋 금지. 최소 변경 원칙. 단, 사용자가 요청·승인한 vault 기록은 해당 노트만 자동 commit/push로 동기화한다.
- git commit 전에 변경 내용이 프로젝트 README에 반영되어야 하는지 확인하고, 필요하면 업데이트. 단순 버그 수정은 불필요, API/기능/설정 변경은 필요.
- 반복되는 교훈만 이 파일이나 프로젝트 지침에 반영한다.
- ~/.claude/ 의 hook/skill을 수정할 때는 {{REPO_DIR}}/ 레포에도 반영 + README.md 업데이트

## 설정 유지보수 (Config Maintenance)
- 설정도 코드처럼 다뤄라 — bloat된 CLAUDE.md는 Claude가 규칙을 무시하게 만든다. "이 줄을 지우면 실수하게 되나?" 아니면 cut.
- 피처 종료나 반복되는 실패가 있을 때 규칙을 검토한다. 항상 필요한 결정적 규칙은 hook, 절차는 skill, 가끔 필요한 맥락은 문서에 둔다.

## Vault (Second Brain)
재사용할 가치가 있는 결정·발견·교훈은 vault 기록을 **제안**한다. 사용자가 요청하거나 승인할 때만
`/vault-note`로 기록한다. 기본 경로는 `~/Documents/vault/`이며, vault 작업은 자동으로 원격과 동기화한다. 충돌·실패는 무시하지 말고 즉시 보고한다.
- 새 작업에서 관련 맥락이 필요하면 `/vault-recall` 또는 `/vault-search`를 명시적으로 사용한다.

- Custom Skills: ~/.claude/skills/ 에 설치됨. /guide로 확인.

## Integrations

- 필요한 MCP 서버와 plugin만 활성화한다. 연결하지 않은 도구나 현재 작업과 무관한 자동화는 기본값으로 가정하지 않는다.
