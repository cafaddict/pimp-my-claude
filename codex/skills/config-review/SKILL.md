---
name: config-review
description: "Codex AGENTS.md·skills·agents·hooks·설정의 중복, 오래된 지시, 끊긴 참조를 점검한다. 설정 점검, config 정리 요청에 사용한다."
---

기본은 읽기 전용 보고서다. 사용자가 `--apply` 또는 수정 요청으로 승인한 범위만 변경한다.
삭제·이동이 승인 범위에 없으면 구체적인 변경안을 먼저 제시한다.

1. **범위**: 전역 `{{CODEX_DIR}}/AGENTS.md`, `config.toml`, `hooks.json`, `agents/`,
   `{{SKILLS_DIR}}/`와 프로젝트의 `AGENTS.md`, `.codex/`, `.agents/skills/`를 살핀다.
   `--project <경로>`가 있으면 그 프로젝트로 한정한다. 중첩 `AGENTS.md`의 적용 범위를 보존한다.
2. **측정**: 파일별 줄 수·수정 시각·명시 경로와 실제 존재 여부를 확인한다.
   Markdown 링크와 리소스 참조를 실제 경로로 해석한다. `@path`를 자동 import라고 가정하지 않는다.
   hook은 `$guide`처럼 JSON과 TOML의 실제 바인딩으로 확인하고, config의 비밀 값은 출력하지 않는다.
3. **판단**: 끊긴 참조, 충돌, 중복, 불필요하게 긴 지시, 오래된 내용을 근거와 함께 분류한다.
   절차형 지시는 skill로, 지속 규칙은 적용 범위에 맞는 `AGENTS.md`로 옮길 후보로 제안한다.
   사용 로그가 없으면 skill이 쓰이지 않는다고 단정하지 않는다.
4. **보고**: `file:line`, 문제, 영향과 최소 변경안을 제시한다. 문서 길이만으로 삭제를 권하지 않는다.
5. **적용**: 기존 승인 범위의 항목만 고치고 관련 형식·설치 검사를 실행한다.
   hook 개발은 `$harness`, 반복 교훈 반영은 `$vault-promote` 절차를 참고한다.
   이 저장소에서 배포한 파일이면 소스 checkout `{{SOURCE_DIR}}`를 먼저 수정하고 문서를 갱신한다.

보고만 했으면 마커도 쓰지 않는다. 사용자가 점검 완료 기록을 요청했을 때만 vault 밖의
`{{CODEX_DIR}}/.config-review-stamp`를 갱신한다. 자동 실행 hook이나 반복 점검을 추가하지 않는다.
