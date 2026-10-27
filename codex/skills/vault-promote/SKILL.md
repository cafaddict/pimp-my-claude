---
name: vault-promote
description: "vault lessons에서 반복되는 교훈을 찾아 프로젝트 AGENTS.md 규칙으로 반영할 초안을 제안한다. 교훈을 규칙으로, vault-promote 요청에 사용한다."
---

VAULT_DIR은 `$PIMP_MY_VAULT_DIR`, 없으면 `~/Documents/vault`이다. 기본은 읽기 전용 제안이다.
분석을 위해 vault pull이 필요하면 `{{INSTALL_DIR}}/bin/vault-sync.sh --pull`을 쓰고,
충돌·실패 시 중단해 보고한다. vault 노트를 수정하지 않는다.

1. `lessons/`의 tags·keywords·본문에서 같은 문제와 해결이 반복되는지 확인한다.
   `--project <이름>`이 있으면 project 필드로 한정한다. 기본 최소 빈도는 3회이며
   `--min-count N`으로 바꿀 수 있다. 같은 세션의 중복 기록을 독립 근거로 세지 않는다.
2. 현재 프로젝트와 중첩 `AGENTS.md`·`AGENTS.override.md`, 전역 `{{CODEX_DIR}}/AGENTS.md`와
   내용을 대조한다. 같은 규칙은 건너뛰고 부분 중복이면 기존 규칙의 수정으로 제안한다.
3. 후보마다 주제, 근거 노트 링크, 반복 조건, 적용 파일과 짧은 규칙 초안을 제시한다.
   언어·디렉토리 한정 규칙은 그 범위를 문장에 명시하거나 해당 디렉토리의 `AGENTS.md`를 쓴다.
   전역 지침 수정은 사용자가 전역 반영을 요청한 경우에만 제안 범위에 넣는다.
4. 사용자가 승인한 후보만 해당 `AGENTS.md`에 반영한다. 기존 규칙을 보존하고,
   새 후보나 범위 변경에만 추가 확인을 받는다. symlink와 override는 실제 적용 대상을 확인한다.
5. 변경한 파일과 규칙, 근거를 보고한다. 프로젝트 변경은 자동으로 commit·push하지 않는다.

`AGENTS.md` 변경은 이후 Codex 세션에서 적용된다. 별도 prose rules 파일의 자동 탐색이나
현재 세션 지침의 즉시 갱신을 약속하지 않는다. vault 저장은 별도의 사용자 요청·승인이 있을 때만 한다.
