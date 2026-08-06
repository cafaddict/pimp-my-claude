# pimp-my-claude

Claude Code 환경을 한 번에 구성하는 도구 모음. Codex CLI용 핵심 skills, 전역 `AGENTS.md`,
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

`setup-codex.sh`는 Codex가 공식적으로 탐색하는 `~/.agents/skills/`에 다음 핵심 workflows를
설치하고, 기존 `~/.codex/AGENTS.md`가 없을 때만 전역 작업 지침을 추가한다.

| 범위 | 설치되는 기능 |
|------|---------------|
| Skills (11) | debugit, review, perf, prompt, plain-words, vault-note/save/recall/search/daily/distill |
| `--with-mcp` | 동일 vault를 검색하는 `vault` stdio MCP (`PIMP_MY_VAULT_DIR` 우선) |
| `--with-hooks` | 문체 강제, 위험 Bash 차단, 완료 알림 |
| `--with-vault` | 기존 Claude 설치와 공유 가능한 Obsidian vault 구조 |

Codex에서 skill은 `$review`, `$vault-note`처럼 `$`로 명시 호출하거나, 요청 내용에 맞으면 자동으로
선택된다. 설치 뒤 새 Codex 세션을 시작하고, hooks는 `/hooks`에서 내용을 검토한 뒤 신뢰하세요.

Claude의 Agent Teams, Claude 전용 subagent 정의, `settings.json`은 Codex와 실행 모델이 달라
자동 설치하지 않는다. 이들은 Codex-native multi-agent 구성으로 별도 포트할 대상이다.

기존 Claude 설치를 다시 실행할 때도 기존 hook 배열은 안전하게 보존한다. 예전에 설치한 vault
briefing·자동 format·transcript hook은 자동으로 지우지 않으므로, 필요 없으면
`~/.claude/settings.json`에서 직접 제거한다.

## 설치 옵션

| 옵션 | 설명 | 필요 조건 |
|------|------|----------|
| (기본) | hooks, skills, agents, settings, CLAUDE.md | Claude Code |
| `--with-vault` | Obsidian vault 구조 생성 + `CLAUDE_VAULT_DIR` 환경변수 등록 | - |
| `--with-mcp` | MCP 시맨틱 검색 서버 (BM25 + fastembed + sqlite-vec) | Python 3.10+ |
| `--with-sdk` | Agent SDK 도구 (claude-review 등) | Python 3.10+ |
| `--all` | 위 3개 전부 설치 | Python 3.10+ |

```bash
# vault 경로 커스텀 (기본: ~/Documents/vault)
CLAUDE_VAULT_DIR=/path/to/vault ./setup.sh --with-vault
```

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
| `/config-review` | harness(CLAUDE.md/rules/skills/hooks/agents) staleness·bloat·중복 감사 → prune/dedup/reroute (vault-promote의 역방향) | 가능 |
| `/vault-note` | vault에 결정/교훈/패턴 기록 | 사용자 요청·승인 시 |
| `/vault-recall [키워드]` | 이전 세션 컨텍스트 복원 (vault 시맨틱 검색) | 가능 |
| `/vault-search [키워드]` | vault 전체 검색 (decisions/lessons/areas/resources/projects) | 사용자만 |
| `/vault-save` | 현재 세션 요약을 vault에 저장 | ✅ 세션 마무리 시 자동 |
| `/vault-daily` | 하루 마무리 정리 (오늘 세션 종합 → daily note) | 사용자만 |
| `/vault-add-project [언어...]` | 프로젝트 초기화 — `.claude/rules/` + vault 프로젝트 폴더 생성 | 사용자만 |
| `/vault-promote` | lessons/에서 반복 교훈 탐지 → `.claude/rules/` 승격 제안 | 사용자만 |
| `/vault-distill [개념]` | event 노트(sessions/lessons/decisions) → `areas/` entity 페이지로 압축·합성 (지식 복리, 출처 추적) | 가능 |
| `/guide` | 설치된 기능 전체 가이드 | 사용자만 |

#### 팀/멀티에이전트 스킬
| 스킬 | 방식 | 설명 |
|------|------|------|
| `/research-team [주제]` | Subagent 병렬 | 독립적인 다관점 리서치 → 종합. 고급·읽기 중심 작업용 |
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
| `code-reviewer` | 코드 리뷰 전문가 (읽기전용, 메모리 축적) | inherit | - |
| `test-writer` | 테스트 생성 전문가 (C++/Python) | inherit | - |
| `implementer` | 코드 구현 (worktree 격리) | inherit | worktree |
| `architect` | 아키텍처/설계 분석 (읽기전용, 메모리 축적) | inherit | - |
| `researcher` | 리서치 전문가 (웹 검색, 문서, 코드베이스) | inherit | - |
| `spec-writer` | 스펙 형식화 전문가 (요구사항→스펙, 코드→스펙 역추출) | inherit | - |
| `spec-verifier` | 스펙 대비 검증 전문가 (skeptical 튜닝) | inherit | - |
| `harness-tester` | harness 컴포넌트 검증 (hook/skill/agent/setting) | sonnet-4-6 | - |

### Hooks (9개 소스, 기본 활성화 4개)

| 훅 | 이벤트 | 설명 |
|----|--------|------|
| vault-briefing | SessionStart | vault 요약 context. **선택형** — 관련 작업에서만 활성화 권장 |
| prompt-hint | UserPromptSubmit | 짧고 모호한 프롬프트 구조 힌트. **선택형** |
| plain-words-remind | UserPromptSubmit | 매 턴 문체 규칙 주입. **기본 활성화** — 긴 세션·compaction 뒤 drift 방지 |
| block-dangerous | PreToolUse (Bash, `if` 1차 필터) | rm -rf, git push --force, DROP TABLE 등 차단 |
| protect-sensitive | PreToolUse (Write/Edit) | .env, credentials, *.pem 등 수정 차단 |
| auto-format | PostToolUse (Write/Edit) | formatter 자동 적용. **선택형** — 기본은 프로젝트 formatter/CI가 기준 |
| pre-compact-save | PreCompact | transcript 백업. **선택형** — 개인정보·저장공간 검토 필요 |
| subagent-stop-log | SubagentStop | 서브에이전트 활동 로그. **선택형** — 구조화된 관측 도구가 있을 때 권장 |
| notify-done | Stop | 작업 완료 알림 (macOS/Linux/Windows) |

### statusLine

컨텍스트 위생 가시화 — 터미널 하단에 `<model> · ctx N% · vault Xd/Yl · <branch>` 상시 표시.
`/compact` 선제 실행 타이밍 판단용. `~/.claude/bin/statusline.sh`에 설치.

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
| vault-notes.md | **/vault/**/*.md | **전역** (`~/.claude/rules/`, setup.sh) |
| plain-words.md | 모든 세션 (glob 없음 → 항상 로드) | **전역** (`~/.claude/rules/`, setup.sh) |
| cpp.md | *.cpp, *.hpp, *.h, *.cc | 프로젝트별 (init-project.sh) |
| python.md | *.py | 프로젝트별 (init-project.sh) |
| rust.md | *.rs | 프로젝트별 (init-project.sh) |
| testing.md | *test*, *spec*, tests/** | 프로젝트별 (init-project.sh) |

## 구조

```
├── setup.sh                  원클릭 설치
├── init-project.sh           프로젝트별 rules/ + vault 프로젝트 초기화
├── hooks/ (9개)              hook 스크립트 (기본 활성화: 문체·안전·완료 알림)
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
- `jq` (settings.json 병합, 선택)
- Python 3.10+ (--with-mcp, --with-sdk 사용 시)
- `gh` CLI (PR 리뷰용, 선택)

## 기여

hook이나 skill을 수정/추가한 경우, 이 README도 함께 업데이트하세요.
