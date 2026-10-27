---
name: vault-add-project
description: "요청한 프로젝트의 AGENTS.md에 언어별 규칙을 반영하고 vault 프로젝트 노트를 만든다. 프로젝트 초기화 요청에만 사용한다."
---

**실행 조건:** 사용자가 이 skill을 직접 호출했거나 프로젝트 초기화를 명시적으로 요청·승인했을 때만
실행한다. 기존 세션의 포괄적 작업 요청을 vault 기록 승인으로 해석하지 않는다.

VAULT_DIR은 `$PIMP_MY_VAULT_DIR`, 없으면 `~/Documents/vault`이다.
언어 인수는 기본 `cpp python`이고 템플릿은 `{{INSTALL_DIR}}/rules-templates/`에서 읽는다.
`testing.md`는 항상 포함한다. 없는 언어 템플릿은 보고하고 건너뛴다.

1. 현재 프로젝트와 기존 `AGENTS.md`·`AGENTS.override.md`를 읽는다. 적용 경로가 불명확하거나
   override 때문에 새 지시가 적용되지 않으면 실제 적용될 파일을 확인한 뒤 진행한다.
2. 요청한 언어 템플릿의 YAML frontmatter는 제거하고, globs는 본문의 조건으로 바꾼다.
   예를 들어 C++ 규칙 앞에 "C++ 파일을 수정할 때"를 붙여 다른 언어에 적용하지 않게 한다.
   자동 format hook이 있다는 문장은 제거하고 프로젝트의 formatter 명령을 필요할 때 실행하게 한다.
3. 프로젝트 `AGENTS.md`의 `<!-- pimp-my-codex:project:start -->`와
   `<!-- pimp-my-codex:project:end -->` 사이에만 규칙을 반영한다.
   마커가 없으면 끝에 추가한다. 기존 문장과 중첩 지침을 보존하고 중복 규칙은 합친다.
   잘못 짝지어진 마커나 symlink면 대상을 확인하고 기존 내용을 덮어쓰지 않는다.
   별도 Markdown rules 디렉토리가 자동 탐색된다고 설명하지 않는다.
4. vault가 존재하면 `projects/<프로젝트명>.md`를 만든다. 이미 있으면 그대로 두고 건너뛴다.
   vault가 없으면 생성 위치를 보고하고 초기화는 별도 요청을 받는다.
   새 노트에는 date, tags: [project], status: active, repo frontmatter와
   개요·기술 스택·관련 결정·관련 세션을 넣는다. README, 빌드 파일과 git remote로 내용을 채운다.
5. 새로 만든 노트 파일만 다음 scoped sync에 전달한다. 이름과 경로는 shell 인수로 안전하게 quote한다.
   ```bash
   {{INSTALL_DIR}}/bin/vault-sync.sh --commit "project: init <프로젝트명>" -- "projects/<프로젝트명>.md"
   ```
   충돌·sync 실패는 즉시 중단하고 보고한다. 노트를 건너뛰었으면 sync하지 않는다.
6. 변경한 지침, 만든 노트와 검사 결과를 보고한다. 프로젝트 코드의 commit·push는 하지 않는다.
