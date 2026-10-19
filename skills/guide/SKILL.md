---
name: guide
description: "/guide를 입력했을 때만 쓴다. 설치된 skills·hooks(실제 바인딩)·agents·vault 구조를 한 표로 보여준다."
disable-model-invocation: true
allowed-tools: Read, Bash, Glob
effort: medium
---

## 작업

읽기만 한다. 파일을 만들거나 고치지 않는다.

1. Skills — SKILL.md 전체를 Read하지 말고 frontmatter의 name·description·disable-model-invocation만 뽑는다.
   `description: |`처럼 여러 줄로 쓴 값은 이어지는 들여쓴 줄까지 출력한다:
   ```bash
   fm() { awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit}
               f && /^(name|description|disable-model-invocation|tools):/{p=1;print;next}
               f && p && /^[[:space:]]/{print;next} {p=0}' "$1" | cut -c1-200; }
   for f in "$HOME"/.claude/skills/*/SKILL.md; do
     echo "== $(basename "$(dirname "$f")")"; fm "$f"
   done
   ```
   `disable-model-invocation: true`면 자동 호출 "사용자만", 아니면 "가능".
2. Hooks — 파일 목록이 아니라 `settings.json`에 실제로 등록된 바인딩을 jq로 **읽는다**:
   ```bash
   S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
   jq -r '.hooks // {} | to_entries[] | .key as $e | .value[] | (.matcher // "") as $m
          | (.hooks // [])[] | "\($e)\t\($m)\t\(.command // .type)\t\(.timeout // "-")"' "$S"
   ls "$HOME/.claude/hooks/"
   ```
   표에는 hook 파일마다 "등록됨(이벤트)" 또는 "파일만 있음"을 적는다. 등록됐지만 파일이 없는 command,
   외부 handler(`~/.claude/hooks/` 밖의 command)도 따로 적는다. 바인딩을 고치라고 직접 수정하지 않는다.
3. Agents — `$HOME/.claude/agents/*.md`의 frontmatter에서 name·description·tools만 뽑는다(1의 `fm` 그대로):
   `for f in "$HOME"/.claude/agents/*.md; do echo "== $(basename "$f" .md)"; fm "$f"; done`
4. Vault — `${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}`의 최상위 디렉토리만 `ls`로 확인한다.

아래 형식으로 정리:

### Skills
| 스킬 | 설명 | 사용법 | 자동 호출 |
|------|------|--------|----------|

### Hooks
| 훅 | 이벤트 | 상태 (등록됨 / 파일만 있음 / 외부 handler) | 설명 |
|----|--------|------------------------------------------|------|

### Agents
| 에이전트 | 역할 | 도구 |
|----------|------|------|

### Vault (Second Brain)
| 디렉토리 | 용도 | 기록 시점 |
|----------|------|----------|
| sessions/ | 세션 기록 | vault-save 요청 시 |
| lessons/ | 교훈/삽질 기록 | vault-note 요청·승인 시 |
| decisions/ | 아키텍처 의사결정 | vault-note 요청·승인 시 |
| projects/ | 프로젝트별 지식 | vault-note / vault-add-project 요청 시 |
| resources/ | 참고 자료 | vault-note 요청·승인 시 |
| areas/ | 지속 관리 영역 | vault-distill 요청 시 / 수동 |
| daily-notes/ | 일일 노트 | vault-daily 요청 시 |

### 유용한 팁
- `& 프롬프트`: 원격 샌드박스에서 무거운 분석 오프로드
- `/doctor`: 환경 문제 자동 진단
- `/context`: 현재 컨텍스트 사용량 확인
- `/hooks`: 등록된 hook 확인
- `Ctrl+G`: 외부 에디터에서 긴 프롬프트 작성
- `Shift+Tab` 두 번: Plan Mode 진입
- `/compact`: 컨텍스트 압축
- `init-project.sh`: 프로젝트별 rules/ + vault 프로젝트 초기화
- 설치된 hook 정의를 이 버전으로 맞추기: 레포에서 `./setup.sh --upgrade-hooks --dry-run`으로 확인 후 `--upgrade-hooks`

마지막에: "더 자세히 알고 싶은 기능이 있으면 `/스킬명`을 입력하세요."
