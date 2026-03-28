# pimp-my-claude

Claude Code 환경을 한 번에 구성하는 도구 모음.
Hooks, Skills, Agents, Vault(Second Brain), MCP 시맨틱 검색, Agent SDK 도구를 포함.

## 빠른 시작

```bash
git clone https://github.com/cafaddict/pimp-my-claude.git
cd pimp-my-claude
./setup.sh                # 기본 (hooks + skills + agents + settings)
./setup.sh --all          # 전부 설치 (vault + MCP + SDK)
```

## 설치 옵션

| 옵션 | 설명 | 필요 조건 |
|------|------|----------|
| (기본) | hooks, skills, agents, settings, CLAUDE.md | Claude Code |
| `--with-vault` | Obsidian vault 구조 생성 + `CLAUDE_VAULT_DIR` 환경변수 등록 | - |
| `--with-mcp` | markdown-vault-mcp + 시맨틱 검색 | Python 3.10+ |
| `--with-sdk` | Agent SDK 도구 (claude-review 등) | Python 3.10+ |
| `--all` | 위 3개 전부 | Python 3.10+ |

```bash
# vault 경로 커스텀 (기본: ~/Documents/vault)
CLAUDE_VAULT_DIR=/path/to/vault ./setup.sh --with-vault
```

## 포함된 기능

### Skills (15개)

#### 단일 세션 스킬
| 스킬 | 설명 | 자동 호출 |
|------|------|----------|
| `/debugit` | 체계적 디버깅 (가설 → 검증 → 수정 → 테스트) | 가능 |
| `/review [PR]` | 코드 리뷰 (정확성/보안/성능/테스트 4관점) | 가능 |
| `/perf` | 성능 분석 (프로파일링 → 병목 → 최적화 → 벤치마크) | 가능 |
| `/prompt` | 프롬프트를 Task/Context/Req/Output 구조로 변환 | 사용자만 |
| `/taskloop [이름]` | Boris 스타일 태스크 루프 (계획→승인→실행→교훈) | 가능 |
| `/note` | vault에 결정/교훈/패턴 자동 기록 | ✅ 항상 자동 |
| `/recall [키워드]` | 이전 세션 컨텍스트 복원 (vault 시맨틱 검색) | 가능 |
| `/save-session` | 현재 세션 요약을 vault에 저장 | ✅ 세션 마무리 시 자동 |
| `/daily` | 하루 마무리 정리 (오늘 세션 종합 → daily note) | 사용자만 |
| `/guide` | 설치된 기능 전체 가이드 | 사용자만 |

#### 팀/멀티에이전트 스킬
| 스킬 | 방식 | 설명 |
|------|------|------|
| `/research-team [주제]` | Subagent 병렬 | 다관점 리서치 → 종합 → vault 저장 |
| `/review-team` | Agent Teams | 경쟁적 3관점 리뷰 (보안/성능/정확성, 서로 반박) |
| `/debug-team` | Agent Teams | 경쟁적 가설 디버깅 (3명이 서로 반증) |
| `/feature-team [피처들]` | Subagent + worktree | 병렬 피처 개발 (피처당 1 에이전트, 격리) |
| `/tdd [기능들]` | Subagent | TDD 사이클 (기능 간 병렬, 기능 내 RED→GREEN 순차) |

### Agents (5개)

| 에이전트 | 역할 | 모델 | 격리 |
|----------|------|------|------|
| `code-reviewer` | 코드 리뷰 전문가 (읽기전용, 메모리 축적) | inherit | - |
| `test-writer` | 테스트 생성 전문가 (C++/Python) | inherit | - |
| `implementer` | 코드 구현 (worktree 격리) | inherit | worktree |
| `architect` | 아키텍처/설계 분석 (읽기전용, 메모리 축적) | inherit | - |
| `researcher` | 리서치 전문가 (웹 검색, 문서, 코드베이스) | inherit | - |

### Hooks (4개)

| 훅 | 이벤트 | 설명 |
|----|--------|------|
| block-dangerous | PreToolUse (Bash) | rm -rf, git push --force 등 차단 |
| protect-sensitive | PreToolUse (Write/Edit) | .env, credentials, *.pem 등 수정 차단 |
| auto-format | PostToolUse (Write/Edit) | black, clang-format, prettier 자동 적용 |
| notify-done | Stop | 작업 완료 알림 (macOS/Linux/Windows) |

### Vault — Second Brain (--with-vault)

```
vault/
├── CLAUDE.md        vault 운영 매뉴얼 (Claude 자동 참조)
├── sessions/        세션 기록 (/save-session 스킬)
├── lessons/         교훈/삽질 기록 (/note 스킬 자동)
├── decisions/       ADR 아키텍처 의사결정 (/note 스킬 자동)
├── projects/        프로젝트별 지식 (/note, init-project.sh)
├── resources/       참고 자료, 패턴 (/note 스킬 자동)
├── areas/           지속 관리 영역 (수동)
├── daily-notes/     일일 정리 (/daily 스킬)
└── templates/       노트 템플릿 4종
```

vault 경로: `$CLAUDE_VAULT_DIR` (기본: `~/Documents/vault`).
`--with-vault` 설치 시 쉘 rc에 자동 등록.

### MCP 시맨틱 검색 (--with-mcp)

markdown-vault-mcp로 vault에 시맨틱 검색 제공:
- FastEmbed (ONNX, CPU-only) — API 키/GPU 불필요
- 하이브리드 검색 (키워드 + 벡터 시맨틱)
- headless Linux 서버에서도 동작 (Obsidian 불필요)

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

| 템플릿 | 적용 대상 |
|--------|----------|
| cpp.md | *.cpp, *.hpp, *.h, *.cc |
| python.md | *.py |
| testing.md | *test*, *spec*, tests/** |

## 구조

```
├── setup.sh                  원클릭 설치
├── init-project.sh           프로젝트별 rules/ + vault 프로젝트 초기화
├── hooks/ (4개)              hook 스크립트
├── skills/ (15개)            skill 정의
├── agents/ (5개)             custom agent 정의
├── rules-templates/ (3개)    cpp, python, testing
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
