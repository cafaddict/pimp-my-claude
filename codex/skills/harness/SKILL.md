---
name: harness
description: "Codex skill·custom agent·hook·설정을 소스 저장소에서 개발하고 임시 환경에서 검증한다. harness, hook 만들기, skill·agent 추가 요청에 사용한다."
---

소스 checkout은 `{{SOURCE_DIR}}`다. 설치본만 고치지 않는다. checkout이 없으면
현재 작업 중인 소스 저장소를 찾고, 소스 위치를 확정할 수 없는 경우에만 사용자에게 확인한다.

1. 요청한 컴포넌트와 변경 범위를 정한다. 이 저장소의 Codex 전용 파일은
   `codex/skills/<name>/SKILL.md`, `codex/agents/<name>.toml`, `codex/hooks.json`에 둔다.
   공통 skill은 `skills/`, 공통 hook은 `hooks/`에 두되 Claude 동작도 검증한다.
2. 여러 파일이나 비명확한 의존성이 있으면 짧은 계획을 제시한다. 동작 정의가 필요하면
   `spec-writer`에 요구사항과 컴포넌트 형식을 전달해 검토 가능한 초안을 만든다.
   기존 승인 범위는 그대로 진행하고 새 동작·배포 결정만 확인한다.
3. 소스에서 최소 변경을 구현한다. skill은 name·description과 필요한 리소스를 포함한다.
   custom agent TOML은 name·description·developer_instructions를 포함하고 별도 model 설정이
   필요하지 않으면 부모 설정을 상속한다. 설정은 문서의 현재 JSON/TOML 형식을 확인한다.
   자동 context 주입·메모리 기록·파일 수정 hook은 기본값으로 추가하지 않는다.
4. `harness-tester`에 변경 범위와 기대 동작을 주고 검증을 맡긴다. 없으면 일반 subagent에
   검증 역할을 주며, subagent 도구가 없으면 직접 검증하고 그 제한을 보고한다.
   installer/hook 실행은 임시 HOME·CODEX_HOME·AGENTS_HOME·vault에서 한다.
   실패 피드백을 고쳐 기본 최대 3회까지 검증하고 남은 실패는 숨기지 않는다.
5. `setup-codex.sh`의 설치 대상·리소스 처리, 관련 테스트와 README를 함께 갱신한다.
   `bash -n`, installer·hook contracts, JSON/TOML 파싱과 `git diff --check`를 실행한다.
6. 사용자가 실제 설치를 요청한 경우에만 `setup-codex.sh`로 배포한다.
   hook 갱신은 `--upgrade-hooks --dry-run` 결과를 검토한 뒤 승인된 범위에서 실행한다.
   사용자 수정본을 보존하고 `/hooks` 신뢰 검토가 필요한 변경은 안내한다.

완료 시 변경 내용, 검사 결과, 설치 여부와 남은 제한을 보고한다. commit·push는 요청받은 경우에만 한다.
