# pimp-my-claude

Claude Code 환경을 한 번에 구성하는 도구 모음. Codex CLI용 전체 23개 skills, custom agents, 전역 `AGENTS.md`,
vault MCP, 선택형 hooks도 함께 제공한다. Hooks, Skills, Agents, Vault(Second Brain), MCP
시맨틱 검색, Agent SDK 도구를 포함.

## 빠른 시작

```bash
git clone https://github.com/cafaddict/pimp-my-claude.git
cd pimp-my-claude
./setup.sh                # 기본 (hooks + skills + agents + settings)
./setup.sh --all          # 전부 설치 (vault + MCP + SDK)

# Codex CLI (Claude 설정은 변경하지 않음)
./setup-codex.sh
./setup-codex.sh --all    # vault + semantic-search MCP + optional hooks
```

## Codex CLI 지원

`review`는 호출 경로·계약과 최소 재현을 확인하고, 확인된 문제와 가설을 나누어 보고한다.
작은 비교 사례와 재실행·채점 방법은 [리뷰 사용 실험](docs/review-evidence-eval.md)을 참고한다.
단일 사례에서 보고 명확성 차이를 관찰한 실험적 절차이며, 일반적인 품질 향상은 입증하지 않았다.

`setup-codex.sh`는 Codex가 공식적으로 탐색하는 `~/.agents/skills/`에 이 저장소의 전체 workflows를
설치하고, 기존 `~/.codex/AGENTS.md`가 없을 때만 전역 작업 지침을 추가한다.

| 범위 | 설치되는 기능 |
|------|---------------|
| 공통 Skills (11) | debugit, review, perf, prompt, plain-words, vault-note/save/recall/search/daily/distill |
| Codex 전용 Skills (12) | config-review, debug-team, feature-team, guide, harness, research-team, review-team, sdd, taskloop, tdd, vault-add-project, vault-promote |
| Custom agents (8) | architect, code-reviewer, harness-tester, implementer, researcher, spec-verifier, spec-writer, test-writer → `~/.codex/agents/*.toml` |
| `--with-mcp` | 동일 vault를 검색하는 `vault` stdio MCP (`PIMP_MY_VAULT_DIR` 우선) |
| `--with-hooks` | 문체 강제, 위험 Bash 차단, 완료 알림 |
| `--with-vault` | 기존 Claude 설치와 공유 가능한 Obsidian vault 구조 |

Codex에서 skill은 `$review`, `$vault-note`처럼 `$`로 명시 호출하거나, 요청 내용에 맞으면 자동으로
선택된다. 설치 뒤 새 Codex 세션을 시작하고, hooks는 `/hooks`에서 내용을 검토한 뒤 신뢰하세요.

공통 skill은 `skills/`에서 호출법·메타데이터를 변환하고, 플랫폼 의존 절차는 `codex/skills/`의
전용 소스를 설치한다. Claude에 별도로 설치한 외부 skill·플러그인은 이 설치기의 대상이 아니다.
Claude의 Agent Teams 대신 Codex subagent를 쓰며, 반론은 메인 agent가 모아 다른 agent에 전달한다.
SDD·TDD는 가능한 경우 새 context를 사용한다. subagent 도구가 없는 환경에서는 순서대로 실행하고
그 제한을 보고한다. worktree는 메인 agent가 실제로 만든 경우에만 분리되며, 기본 git commit·push는 하지 않는다.

`$vault-add-project cpp python`은 설치된 언어 템플릿을 프로젝트 `AGENTS.md`의 표시된 구간에 반영한다.
기존 지침을 보존하고 언어별 적용 조건을 본문에 명시한다. `$vault-promote`도 승인한 교훈을
`AGENTS.md`에 반영한다. `$taskloop`의 작업 기록은 `.codex/tasks/`에 둔다.
`$guide`, `$prompt`, `$vault-daily`, `$vault-add-project`는 `agents/openai.yaml`로 명시 호출 정책을 유지한다.
Vault 기록은 요청·승인 후에만 만들고 해당 파일만 scoped sync한다.

Custom agent는 [공식 standalone TOML 형식](https://learn.chatgpt.com/docs/agent-configuration/subagents)을
지원하는 Codex가 필요하다. agent의 model·reasoning·권한은 부모 설정을 따르며, 읽기 전용 역할 지시는
별도 sandbox를 만들지 않는다. 설치기는 기존 `config.toml`을 바꾸지 않는다.
전역 `AGENTS.md` 템플릿도 별도 multi-agent skill의 사용을 강제하지 않는다.
Claude 전용 `settings.json`, statusline, Agent SDK 도구는 그대로 Claude 설치 대상이다.

기존 Claude 설치를 다시 실행할 때도 기존 hook 배열은 안전하게 보존한다. 예전에 설치한 vault
briefing·자동 format·transcript hook은 자동으로 지우지 않으므로, 필요 없으면
`~/.claude/settings.json`에서 직접 제거한다. 설치된 hook 정의·스크립트를 이 버전으로 바꾸는 방법은
아래 [업그레이드와 복구](#업그레이드와-복구)를 본다. Codex도 같은 방식이다(`./setup-codex.sh --upgrade-hooks`).

## 설치 옵션

| 옵션 | 설명 | 필요 조건 |
|------|------|----------|
| (기본) | hooks, skills, agents, settings, CLAUDE.md | Claude Code |
| `--with-vault` | Obsidian vault 구조 생성 + `CLAUDE_VAULT_DIR` 환경변수 등록 | - |
| `--with-mcp` | MCP 시맨틱 검색 서버 (BM25 + fastembed + sqlite-vec) | Python 3.10+ |
| `--with-sdk` | Agent SDK 도구 (claude-review 등) | Python 3.10+ |
| `--all` | 위 3개 전부 설치 | Python 3.10+ |
| `--upgrade-hooks` | 설치된 hook 정의·스크립트만 현재 템플릿으로 갱신(diff 출력 → 백업 → 적용). 다른 설치는 하지 않음 | jq |
| `--dry-run` | `--upgrade-hooks`와 함께: 바뀔 내용만 출력, 아무것도 쓰지 않음 | jq |

```bash
# vault 경로 커스텀 (기본: ~/Documents/vault)
CLAUDE_VAULT_DIR=/path/to/vault ./setup.sh --with-vault
```

## 업그레이드와 복구

**기본 재실행(`./setup.sh`)은 기존 설정이 우선이다.**

- `settings.json`: 없는 키와 없는 hook만 더한다. 같은 이벤트에 같은 command가 이미 있으면 템플릿 handler를
  더하지 않는다(예전처럼 같은 hook이 두 번 등록되지 않는다). `statusLine`은 기존 값을 통째로 유지한다.
  바뀌는 내용이 있으면 쓰기 전에 `~/.claude/pimp-my-claude-backups/<UTC 시각>/settings.json`에 백업한다.
- 설치된 파일(hooks, bin, skills, agents, rules): 없으면 설치하고, 이 레포가 예전에 배포한 판과 바이트까지
  같으면(git 기록으로 확인) 새 판으로 바꾼다. 직접 고친 파일은 덮어쓰지 않고 목록만 보여 준다.
  hook 스크립트는 예전 배포판이어도 기본 재실행에서는 바꾸지 않는다(`--upgrade-hooks` 몫).
  git clone이 아닌 사본에서 실행하면 예전 판을 확인할 수 없으므로 다른 파일은 모두 "직접 고친 파일"로 보고 둔다.
- Codex skill 사본(`~/.agents/skills/<skill>/SKILL.md`, 리소스와 호출 정책), custom agent와 규칙 템플릿도
  같은 규칙이다. 예전 설치 스크립트들이
  렌더링한 판(git 기록 + 그때의 렌더링 규칙)과 같으면 새 판으로 바꾸고, 그 밖의 파일은 직접 고쳤거나 출처를
  판별할 수 없는 사본으로 보고 그대로 둔 채 목록만 보여 준다. skill 폴더에 직접 더한 파일은 건드리지 않는다.
  보류된 파일을 레포 판으로 바꾸려면 `mv <파일> <파일>.mine && ./setup-codex.sh`, 비교는
  `diff -u <파일>.mine <파일>`, 되돌리기는 `mv <파일>.mine <파일>`. `--upgrade-hooks`는 skill을 건드리지 않는다.
- 설치된 파일은 어떤 경우에도 지우지 않는다.
- 아래 경우에는 아무 파일도 쓰기 전에 멈춘다(exit 1/2): `settings.json`(Codex는 `hooks.json`)이 symlink일 때
  (dotfiles 연결을 끊지 않도록 — 대상 파일을 직접 편집), JSON이 깨졌거나 `hooks` 구조를 해석할 수 없을 때,
  레포 경로(Codex는 `CODEX_HOME`·`AGENTS_HOME`)에 공백이나 셸 특수문자(`' " \ $ ; & | < > ( ) * ? [ ] { } ! #`, 백틱)가
  있을 때(skill·hook의 실행 줄이 경로를 따옴표 없이 쓰기 때문). 한글 같은 비ASCII 경로는 된다.

**명시적 업그레이드:**

```bash
./setup.sh --upgrade-hooks --dry-run   # 바뀔 내용(diff)만 보기
./setup.sh --upgrade-hooks             # 백업 후 적용, 되돌리기 명령 출력
```

- 템플릿 command와 같은 handler라도 **정의 전체가 이 레포가 배포했던 판과 같을 때만** 새 정의로 바꾼다.
  필드를 더하거나 고친 handler는 같은 command의 handler 전부를 그대로 두고 "보류"로 보고한다.
- 같은 handler가 여러 group에 있으면 matcher(그 밖의 group 필드 포함)가 같은 group 사이의 중복만 "중복 제거"한다.
  다른 matcher group(예: 직접 더한 `NotebookEdit`)에 둔 사본은 그 matcher와 함께 남는다.
- 은퇴한 hook(`prompt-hint`)은 바인딩만 푼다. `~/.claude/hooks/prompt-hint.sh` 파일은 남는다.
- 외부 handler(예: 다른 도구의 statusLine, `:` 같은 직접 등록한 command)와 선택형 hook(vault-briefing,
  pre-compact-save, subagent-stop-log, auto-format)은 건드리지 않는다. timeout이 600초를 넘는 정의는 안내만 한다.
- 바뀌는 것이 없으면 백업도 만들지 않는다. 다시 실행해도 결과는 같다.

**복구:** 업그레이드는 `~/.claude/pimp-my-claude-backups/<UTC 시각>/`에 바꾸기 전 `settings.json`과 hook
스크립트를 남기고, 같은 폴더의 `restore-commands.txt`에 되돌리는 `cp -p` 명령을 적는다. 그 명령을 실행하면
업그레이드 전과 바이트까지 같아진다. 백업 폴더는 매번 새로 만들고 덮어쓰지 않는다. Codex는
`~/.codex/pimp-my-codex/backups/<UTC 시각>/`를 쓴다. 이 레포 자체를 되돌릴 때는 해당 commit을 revert한 뒤
임시 HOME에서 `bash tests/test-installers.sh`로 확인하고 실제 재설치를 한다.

**한계:** 소스에서 hook을 지우거나 고쳐도 이미 설치된 `settings.json` 바인딩과 파일은 그대로다. 바인딩은
`--upgrade-hooks`로만 바뀐다. Codex는 hook 정의가 바뀌면 `/hooks`에서 다시 신뢰해야 할 수 있다.
예전 판 판별은 이 레포의 git 기록과 그때의 렌더링 규칙에 기대므로, 설치 뒤 `CODEX_HOME`/`AGENTS_HOME`을 바꿨거나
다른 fork에서 설치한 Codex skill 사본은 "출처 불명"으로 보류된다(위 `mv … .mine` 방법으로 직접 정리).

## 포함된 기능

### Skills (23개, vault-* 8개 + 개발 15개)

#### 단일 세션 스킬
| 스킬 | 설명 | 자동 호출 |
|------|------|----------|
| `/debugit` | 체계적 디버깅 (가설 → 검증 → 수정 → 테스트) | 가능 |
| `/review [PR]` | 코드 리뷰 (정확성/보안/성능/테스트 4관점) | 가능 |
| `/perf` | 성능 분석 (프로파일링 → 병목 → 최적화 → 벤치마크) | 가능 |
| `/prompt` | 프롬프트를 Task/Context/Req/Output 구조로 변환 | 사용자만 |
| `/plain-words` | 쉬운 단어로 쓰기 — 논문식 한자어(유휴/축출/이질적)·영어 격식어(utilize/facilitate)는 풀고, 정착된 기술 용어(queue/TTFT/threshold)는 억지 번역 금지 | 가능 |
| `/taskloop [이름]` | Boris 스타일 태스크 루프 (계획→승인→실행→교훈) | 가능 |
| `/config-review` | harness(CLAUDE.md/rules/skills/hooks/agents) staleness·bloat·중복 감사 → prune/dedup/reroute (vault-promote의 역방향). 리포트만 낼 때는 파일을 쓰지 않음 | 가능 |
| `/vault-note` | vault에 결정/교훈/패턴 기록 | 사용자 요청·승인 시 |
| `/vault-recall [키워드]` | 이전 세션 컨텍스트 복원 (vault 시맨틱 검색) | 가능 |
| `/vault-search [키워드]` | vault 전체 검색 (decisions/lessons/areas/resources/projects) | 사용자만 |
| `/vault-save` | 현재 세션 요약을 vault에 저장 | 사용자 요청·승인 시 (마무리 시 제안) |
| `/vault-daily` | 하루 정리 (오늘 세션 종합 → daily note, 직접 호출할 때만 기록·sync) | 사용자만 |
| `/vault-add-project [언어...]` | 프로젝트 초기화 — `.claude/rules/` + vault 프로젝트 폴더 생성 | 사용자만 |
| `/vault-promote` | lessons/에서 반복 교훈 탐지 → `.claude/rules/` 승격 제안 | 사용자만 |
| `/vault-distill [개념]` | event 노트(sessions/lessons/decisions) → `areas/` entity 페이지로 압축·합성 (지식 복리, 출처 추적) | 가능 |
| `/guide` | 설치된 기능 전체 가이드 (hook은 settings.json의 실제 바인딩 기준) | 사용자만 |

**리뷰 고르기:** `/review`는 이 레포 skill이다. 지금 대화 맥락에서 SPEC·요구사항 대비 근거(호출 경로, 최소 재현)를 확인한다.
Claude Code 내장 `/code-review`는 새 subagent에서 버그 위주로 본다(effort, `--fix`, `--comment`). skill 이름이 `review`여도
`/code-review`는 따로 쓸 수 있다(2.1.310 `-p`에서 프로젝트 skill로 확인). 같은 세션 리뷰와 새 맥락(`context: fork`) 리뷰를
비교한 작은 실험에서는 품질 차이를 관찰하지 못했고 비용은 조금 늘어 review skill은 바꾸지 않았다:
[새 맥락 리뷰 실험](docs/review-fresh-context-eval.md). 인자를 받는 skill(`argument-hint`나 `arguments` 선언)에
`context: fork`를 붙일 때는 본문에 `$ARGUMENTS`가 있어야 `/skill` 뒤의 요청이 subagent에 모두 전달된다.

#### 팀/멀티에이전트 스킬
| 스킬 | 방식 | 설명 |
|------|------|------|
| `/research-team [주제]` | Subagent 병렬 | 독립적인 다관점 리서치 → 종합. vault 저장은 제안만 하고, 사용자가 승인하면 `/vault-note`로 한 번 기록 |
| `/review-team` | Agent Teams | 경쟁적 3관점 리뷰. 고급·실험적 기능일 수 있음 |
| `/debug-team` | Agent Teams | 경쟁적 가설 디버깅. 고급·실험적 기능일 수 있음 |
| `/feature-team [피처들]` | Subagent + worktree | 독립 모듈만 병렬 개발. 공유 파일은 병렬 할당 금지 |
| `/tdd [기능들]` | Subagent | TDD 사이클 (기능 간 병렬, 기능 내 RED→GREEN 순차) |
| `/sdd [요구사항]` | Subagent Loop | Spec-Driven Development (스펙→구현↔검증 피드백 루프, `--reverse`로 코드→스펙 역추출) |
| `/harness [설명]` | Subagent Loop | Harness 컴포넌트 개발 (스펙→구현↔테스트→배포) |

#### plain-words — 3계층 (스킬 + 전역 rule + 상시 훅)

"쉽게 써줘"에 대한 Claude의 **두 가지** 실패를 동시에 막는다. 실패 모드가 두 개이고
처방이 반대라는 게 핵심이다.

| | 증상 | 예 | 처방 |
|---|---|---|------|
| A | 논문식 한자 학술어 | 유휴, 축출, 이질적, 열화, 강건성 | 풀어 쓰기 / 영어 (idle, evict) |
| B | 정착된 용어를 창작 번역 (**더 나쁨**) | 줄 밀림 비용, 대기줄, 기준값, 딱지 | 원어 유지 (큐잉 지연, threshold) |

축은 한국어 vs 영어가 아니다. `idle`은 영어라도 쉽고(매일 말한다) `유휴`는 한국어라도
어렵다(논문에만 있다). 기준 한 줄: **"이 분야 사람이 회의에서 이 단어를 말하는가?"**
영어에도 동일 적용 (utilize→use, "it should be noted that"→삭제, 단 `backpressure`는 유지). <!-- plain-words: ignore -->

스킬은 온디맨드이고 요약 규칙은 전역 rule로 둔다. 매 턴 hook은 긴 세션과 compaction 뒤에도
문체 규칙을 강제한다. 전체 대조표는 스킬(`/plain-words`)에 있다.
근거와 한계: [`skills/plain-words/README.md`](skills/plain-words/README.md)

```bash
# 파일로 쓴 산문 기계 검사 (SKILL.md의 대조표를 런타임 파싱, 규칙 84개)
python skills/plain-words/scripts/check.py docs/*.md
```

### Agents (8개)

| 에이전트 | 역할 | 모델 | 격리 |
|----------|------|------|------|
| `code-reviewer` | 코드 리뷰 전문가 (코드 비수정, `memory: project`라 memory 디렉터리에는 씀) | inherit | - |
| `test-writer` | 테스트 생성 전문가 (C++/Python) | inherit | - |
| `implementer` | 코드 구현 (worktree 격리) | inherit | worktree |
| `architect` | 아키텍처/설계 분석 (코드 비수정, `memory: project`라 memory 디렉터리에는 씀) | inherit | - |
| `researcher` | 리서치 전문가 (웹 검색, 문서, 코드베이스). 파일을 쓰지 않고 호출자에게 보고. Bash가 있어 도구 수준의 읽기 전용은 아님 | inherit | - |
| `spec-writer` | 스펙 형식화 전문가 (요구사항→스펙, 코드→스펙 역추출) | inherit | - |
| `spec-verifier` | 스펙 대비 검증 전문가 (skeptical 튜닝) | inherit | - |
| `harness-tester` | harness 컴포넌트 검증 (hook/skill/agent/setting) | sonnet-4-6 | - |

### Hooks (8개 소스, 기본 활성화 4개)

| 훅 | 이벤트 | 설명 |
|----|--------|------|
| vault-briefing | SessionStart | vault 요약 context. **선택형** — 관련 작업에서만 활성화 권장 |
| plain-words-remind | UserPromptSubmit | 매 턴 문체 규칙 주입. **기본 활성화** — 긴 세션·compaction 뒤 drift 방지 (timeout 5초) |
| block-dangerous | PreToolUse (Bash) | `rm -rf`로 `/`·`/*`·`~`·`$HOME`·`.` 삭제, `git push -f/--force`, `git reset --hard`, `git clean -fd`, `DROP TABLE/DATABASE` 차단(exit 2). `/bin/rm`·`\rm`처럼 쓴 명령과 `sudo`·`env`·`nice`·`timeout` 래퍼 뒤의 명령도 본다. 따옴표 안 문자열(`echo "rm -rf /"`)은 막지 않고, `python -c`·변수로 만든 명령은 못 잡는다. 좁은 guardrail이며 native permissions를 대신하지 않는다. 입력 JSON을 해석하지 못하면 원시 입력으로 같은 검사를 하고, 위험 명령이 없으면 exit 1(non-blocking error)로 알린다 |
| protect-sensitive | PreToolUse (Write/Edit) | .env, credentials, *.pem 등 수정 차단. jq가 없으면 검사 없이 통과하는 한계가 있다 |
| auto-format | PostToolUse (Write/Edit) | formatter 자동 적용. **선택형** — 기본은 프로젝트 formatter/CI가 기준 |
| pre-compact-save | PreCompact | compaction 직전 원본 transcript 백업. **선택형** — 대화 전체가 들어 있으니 개인정보·저장공간 검토 필요. 위치: `${PIMP_MY_PRE_COMPACT_DIR:-~/.claude/pre-compact-backups}` (새로 만들 때 700, 파일 600. 이미 있던 디렉터리 권한은 바꾸지 않는다). 같은 이름이 있으면(동시 호출, symlink 포함) 덮어쓰거나 따라가지 않고 다른 이름으로 쓴다. Claude Code 세션 파일은 기본 30일 뒤 지워지므로 오래 남는 사본은 이것뿐이다 |
| subagent-stop-log | SubagentStop | subagent 종료 이력(`agent_type`, `agent_id`, `hint=error-word`는 마지막 메시지의 단어 힌트일 뿐 판정 아님). 메시지 본문은 기록 안 함. **선택형**. 위치: `${PIMP_MY_LOG_DIR:-~/.claude/pimp-logs}/subagent-activity.log` (새로 만든 파일 600, 이미 있던 파일 권한은 그대로). 빈 값은 `unknown`으로 적는다 |
| notify-done | Stop | 작업 완료 알림 (macOS/Linux/Windows) |

`prompt-hint`는 이번 버전에서 소스에서 뺐다(짧은 승인 프롬프트에도 "질문 먼저"를 넣어 CLAUDE.md 규칙과 충돌).
이미 등록했다면 `./setup.sh --upgrade-hooks`가 바인딩만 풀고 파일은 남긴다.

pre-compact-save·subagent-stop-log는 예전에 vault의 `sessions/pre-compact/`, `sessions/subagent-activity.log`에 썼다.
그 파일들은 옮기거나 지우지 않는다. `bin/vault-sync.sh`는 이 두 경로를 commit 대상으로 받지 않는다. 다만 이미
commit됐거나 push되지 않은 채 남은 사본은 이 스크립트가 다루지 않으므로 vault에서 직접 확인한다. 새 vault의
`.gitignore`에는 두 경로가 들어 있고, 기존 vault `.gitignore`는 자동으로 고치지 않는다.
예전 위치를 계속 쓰려면 `PIMP_MY_PRE_COMPACT_DIR`, `PIMP_MY_LOG_DIR`를 지정한다(그 경우 git 제외는 직접 관리).

### statusLine

Starship 프롬프트 재현 — 터미널 하단에 powerline 세그먼트(user · directory · git branch/status · language · docker · time · model·effort · ctx% · rate limits)를 Starship pastel-powerline 계열 고정 색상으로 표시.
model 세그먼트는 현재 세션의 reasoning effort를 함께 표시(`🤖 Opus · high`) — 모델이 effort를 보고하지 않으면 생략.
`~/.claude/bin/statusline.sh`에 설치. 끝의 model/ctx% 세그먼트는 `/compact` 선제 실행 타이밍 판단용.
rate limits 세그먼트(`⏳ 5h NN%  7d NN%`)는 Claude.ai 구독 5시간 윈도우/주간 사용률 — 정보 없으면 자동 생략.
글리프 표시에는 Nerd Font가 필요하다. 언어 세그먼트는 `Cargo.toml`·`package.json`·`go.mod` 같은 파일 존재만 보고
`rustc`/`node`/`go`/`python3`를 실행하지 않는다(toolchain 자동 다운로드·작업 폴더가 고른 실행 파일 실행 방지).
Claude Code는 workspace trust를 수락하기 전에는 statusLine을 실행하지 않는다.
`settings.json`에 이미 다른 `statusLine`이 있으면 setup은 그 값을 바꾸지 않는다. 이 statusLine을 쓰려면 직접 바꾼다.
이전 한 줄 형식(`vault Xd/Yl` 포함)으로 되돌리려면 `git show b6a362d:bin/statusline.sh > ~/.claude/bin/statusline.sh`.

### AGENTS.md (업계 표준 호환)

`~/.claude/AGENTS.md` → `CLAUDE.md` symlink 자동 생성. Linux Foundation AAIF AGENTS.md 표준 (Cursor/Codex/Windsurf 호환).
CLAUDE.md만 관리하면 AGENTS.md가 자동으로 따라감.

### Vault — Second Brain (--with-vault)

```
vault/
├── CLAUDE.md        vault 운영 매뉴얼 (Claude 자동 참조)
├── sessions/        세션 기록 (/vault-save)
├── lessons/         교훈/삽질 기록 (/vault-note, 사용자 요청·승인 시)
├── decisions/       ADR 아키텍처 의사결정 (/vault-note, 사용자 요청·승인 시)
├── projects/        프로젝트별 지식 (/vault-note, /vault-add-project)
├── resources/       참고 자료, 패턴 (/vault-note, 사용자 요청·승인 시)
├── areas/           지속 관리 영역 (수동)
├── daily-notes/     일일 정리 (/vault-daily)
└── templates/       노트 템플릿 6종 (session, decision, daily, project, lesson, resource)
```

vault 경로: `$PIMP_MY_VAULT_DIR` 우선, Claude에서는 `$CLAUDE_VAULT_DIR`도 지원 (기본: `~/Documents/vault`).
`--with-vault` 설치 시 쉘 rc에 자동 등록.

**노트 품질 가이드**: enriched frontmatter (summary, topics, keywords, confidence, importance), 링크 무결성 검증 (Glob 확인 + 양방향 링크 + 고아 방지), 내용 깊이 요구 (인사이트, 대안 비교, 적용 방법). 시간은 KST 기준. vault 작업은 자동으로 원격과 동기화하며, 충돌은 무시하지 않고 중단·보고한다.

**자동 동기화 범위 (`bin/vault-sync.sh`)**: 사용자가 요청·승인한 vault 기록에 대해서만 skill이 실행한다.

- `--commit "<메시지>" -- <파일...>`는 나열한 vault 상대 경로 파일만 commit·push한다. 다른 staged/unstaged/untracked 변경은
  stash로 잠시 보호했다가 staged 상태까지 그대로 되돌리며, commit에도 push에도 섞이지 않는다.
- 절대 경로, `..`, `.git` 안 경로, 디렉터리, 없는 파일은 저장소를 건드리기 전에 거부한다. glob·pathspec magic은 글자 그대로 취급한다.
- `sessions/pre-compact/` 아래 파일과 `sessions/subagent-activity.log`(예전 hook이 남긴 원본 transcript·로그)도 거부한다.
  이미 commit된 사본을 정리하지는 않는다.
- 다음 경우에는 아무것도 commit·push하지 않고 중단한다: 다른 sync 실행 중(`.git/pimp-vault-sync.lock`), merge/rebase 진행 중,
  pull 실패, 로컬 변경 복원 충돌, 아직 push하지 않은 이전 로컬 commit이 있음(원격 브랜치가 아직 없을 때 기존 history 포함).
  이전 commit은 직접 검토해 `git push -u origin <branch>`로 한 번 올린 뒤 다시 실행한다.

복구 방법: 중단 메시지에 나온 stash(`git stash list`에서 `pimp-my-claude auto-sync`, SHA 함께 표시)는 지워지지 않는다. pull 실패라면
pull 문제를 해결한 뒤 `git stash pop --index <stash>`로 되돌린다(`pop`은 복원에 성공했을 때만 stash를 지운다).
복원 충돌이라면 아무것도 복원되지 않았을 수도 있고(stage한 파일이 받아 온 노트와 겹칠 때), 일부만 복원됐을 수도 있다
(새로 만든 로컬 노트와 같은 경로의 파일을 원격에서 받아 왔을 때, 작업 트리에는 원격 버전만 남는다). 이때 stash가 유일한 사본일 수 있다.
메시지에 나온 경로별 `git show '<SHA>:<경로>'`(작업 트리), `'<SHA>^2:<경로>'`(staged), `'<SHA>^3:<경로>'`(untracked)로 저장본을 확인하고,
덮어쓰지 말고 `git show '<SHA>^3:<경로>' > '<경로>.local'`처럼 옆에 꺼내 직접 합친다. 전체 목록은
`git stash show --include-untracked --name-status <SHA>`. **모든 변경을 되살리고 확인하기 전에는 그 stash를 drop/clear하지 않는다.**
lock이 남았는데 실행 중인 sync가 없다면 `rmdir .git/pimp-vault-sync.lock`. 설치본(`~/.claude/bin/`,
`~/.codex/pimp-my-codex/bin/`)은 `setup.sh`/`setup-codex.sh`를 다시 실행해야 이 동작으로 갱신된다.

**두 레이어 (event + entity)**: `sessions/lessons/decisions`(시간순·불변 event 로그)는 긴 세션의 context pollution을 막고, `areas/`(개념순·가변 entity 페이지)는 `/vault-distill`로 event를 압축해 지식을 복리시킨다. 현재 MCP는 hybrid relevance와 type/project 필터를 제공하며, `importance`·`superseded_by`는 노트 품질 메타데이터다.

### MCP 시맨틱 검색 (--with-mcp)

BM25 키워드 + 벡터 시맨틱 하이브리드 검색을 제공하는 자체 MCP 서버:
- **fastembed** (ONNX, CPU-only) — API 키/GPU 불필요
- **paraphrase-multilingual-MiniLM-L12-v2** — 한/영 다국어 임베딩 (384dim, ~220MB)
- **sqlite-vec + FTS5** — 단일 .db 파일, 외부 DB 불필요
- **RRF 융합** — 키워드와 시맨틱 결과를 자동 결합
- **자동 증분 인덱싱** — 검색 시 변경된 파일 자동 반영
- headless Linux 서버에서도 동작 (Obsidian 불필요)

MCP 없이도 Grep 기반 키워드 검색으로 모든 스킬이 동작합니다.

### Agent SDK 도구 (--with-sdk)

| 명령어 | 설명 |
|--------|------|
| `claude-review --pr 123` | PR 자동 리뷰 (Opus + Pydantic 구조화 출력) |
| `claude-scan --dir ./src` | 코드베이스 보안 스캔 (OWASP Top 10) |
| `claude-report` | 일일 코드 변경 요약 |

모든 도구에 `--budget`(비용 한도), `--json`(구조화 출력) 옵션 지원.

### Rules 템플릿

```bash
./init-project.sh cpp python    # .claude/rules/ + vault 프로젝트 폴더 생성
```

| 템플릿 | 적용 대상 | 배포 |
|--------|----------|------|
| vault-notes.md | vault 루트의 sessions/·decisions/·lessons/·resources/·areas/·projects/·daily-notes/ (vault 를 작업 디렉터리로 연 세션) | **전역** (`~/.claude/rules/`, setup.sh) |
| plain-words.md | 모든 세션 (glob 없음 → 항상 로드) | **전역** (`~/.claude/rules/`, setup.sh) |
| cpp.md | *.cpp, *.hpp, *.h, *.cc | 프로젝트별 (init-project.sh) |
| python.md | *.py | 프로젝트별 (init-project.sh) |
| rust.md | *.rs | 프로젝트별 (init-project.sh) |
| testing.md | *test*, *spec*, tests/** | 프로젝트별 (init-project.sh) |

## 구조

```
├── setup.sh                  원클릭 설치
├── init-project.sh           프로젝트별 rules/ + vault 프로젝트 초기화
├── hooks/ (8개)              hook 스크립트 (기본 활성화: 문체·안전·완료 알림)
├── lib/                      설치 스크립트 공용 함수 (hook 병합·업그레이드)
├── bin/ (2개)                statusline, vault 자동 동기화 스크립트
├── skills/ (23개)            skill 정의
├── agents/ (8개)             custom agent 정의
├── mcp/                      자체 MCP 시맨틱 검색 서버 (fastembed + sqlite-vec)
├── rules-templates/ (6개)    vault-notes·plain-words (전역), cpp, python, rust, testing
├── vault-template/           vault 디렉토리 구조 + 템플릿
├── agent-tools/              Agent SDK Python 프로젝트
├── settings-template.json    hooks/env 설정
└── CLAUDE-template.md        CLAUDE.md 템플릿
```

## 요구사항

- Claude Code v2.1.32+
- `jq` (settings.json 병합·`--upgrade-hooks`, 선택)
- Python 3.10+ (--with-mcp, --with-sdk 사용 시)
- `gh` CLI (PR 리뷰용, 선택)

## 기여

hook이나 skill을 수정/추가한 경우, 이 README도 함께 업데이트하세요.
