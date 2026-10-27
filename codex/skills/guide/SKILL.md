---
name: guide
description: "사용자가 $guide 또는 설치 기능 안내를 요청했을 때 Codex skills·hooks·agents·vault 현황을 읽어서 보여준다."
---

읽기만 한다. 설정을 고치거나 vault sync·색인을 실행하지 않는다.
전역 경로는 설치 시 정해진 `{{CODEX_DIR}}`와 `{{SKILLS_DIR}}`이고, 프로젝트의
`.codex/`와 `.agents/skills/`도 함께 살펴본다. 현재 세션에서 보이는 skill 목록이 있으면 대조한다.

1. **Skills**: 각 `SKILL.md`의 frontmatter에서 name·description만 읽는다. 여러 줄 description도
   보존한다. `agents/openai.yaml`의 `policy.allow_implicit_invocation: false`면 명시 호출 전용으로
   표시한다. user/project `config.toml`의 `[[skills.config]]` 비활성화도 확인한다.
2. **Hooks**: 전역·프로젝트 `hooks.json`의 `.hooks`와 `config.toml`의 `[hooks]`를 파싱한다.
   JSON의 바인딩은 다음처럼 추출할 수 있다. 파일이 없으면 건너뛴다.
   ```bash
   jq -r '.hooks // {} | to_entries[] | .key as $e | .value[] | (.matcher // "") as $m
     | (.hooks // [])[] | "\($e)\t\($m)\t\(.command // .type)"' "{{CODEX_DIR}}/hooks.json"
   ```
   등록 이벤트·matcher·command를 보여주고, 스크립트만 있는 경우와 경로가 없는 바인딩을 구분한다.
   `/hooks`의 신뢰 상태는 파일 존재만으로 판단하지 않는다. 확인할 수 없으면 검토가 필요하다고 적는다.
3. **Agents**: 전역·프로젝트 `agents/*.toml`의 name·description을 읽는다.
   `config.toml`의 `[agents.<name>]` 선언도 확인한다. 명시 model이 없으면 부모 설정 상속으로 표시한다.
   agent 파일의 읽기 전용 지시는 권한 강제가 아님을 구분한다.
4. **Vault**: `${PIMP_MY_VAULT_DIR:-$HOME/Documents/vault}` 최상위 디렉토리만 확인한다.
   없으면 미설치로 표시한다. 노트 본문과 인증 정보는 읽을 필요가 없다.

TOML은 가능하면 Python `tomllib` 등 parser로 읽는다. 사용할 수 없으면 해당 부분을 수동 확인
대상으로 표시한다. config 전체나 MCP env·토큰을 출력하지 않는다.
기능별로 이름, 설명, 사용법, 설치·활성화 확인 상태를 표로 보고한다.
