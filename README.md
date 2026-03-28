# pimp-my-claude

Claude Code 환경을 한 번에 구성하는 도구 모음.

## 빠른 시작

```bash
git clone https://github.com/cafaddict/pimp-my-claude.git
cd pimp-my-claude
./setup.sh                # 기본 (hooks + skills + settings)
./setup.sh --all          # 전부 설치 (vault + MCP + SDK)
```

## 설치 옵션

| 옵션 | 설명 | 필요 조건 |
|------|------|----------|
| (기본) | hooks, skills, settings, CLAUDE.md | Claude Code |
| `--with-vault` | Obsidian vault 구조 생성 | - |
| `--with-mcp` | markdown-vault-mcp + 시맨틱 검색 | Python 3.10+ |
| `--with-sdk` | Agent SDK 도구 (claude-review 등) | Python 3.10+ |
| `--all` | 위 3개 전부 | Python 3.10+ |

## 포함된 기능

### Skills (7개)

| 스킬 | 설명 |
|------|------|
| `/debugit` | 체계적 디버깅 (가설 → 검증 → 수정 → 테스트) |
| `/review [PR]` | 코드 리뷰 (정확성/보안/성능/테스트) |
| `/perf` | 성능 분석 (프로파일링 → 병목 → 최적화) |
| `/prompt` | 프롬프트를 Task/Context/Req/Output 구조로 변환 |
| `/taskloop [이름]` | Boris 스타일 태스크 루프 (계획→승인→실행→교훈) |
| `/recall [키워드]` | 이전 세션 컨텍스트 복원 (vault 시맨틱 검색) |
| `/guide` | 설치된 기능 전체 가이드 |

### Hooks (5개)

| 훅 | 이벤트 | 설명 |
|----|--------|------|
| block-dangerous | PreToolUse (Bash) | rm -rf, git push --force 등 차단 |
| protect-sensitive | PreToolUse (Write/Edit) | .env, credentials 등 수정 차단 |
| auto-format | PostToolUse (Write/Edit) | black, clang-format, prettier 자동 적용 |
| session-save | Stop | 세션 종료 시 vault에 세션 기록 자동 저장 |
| notify-done | Stop | 작업 완료 알림 (macOS/Linux/Windows) |

### Vault (--with-vault)

```
vault/
├── CLAUDE.md        vault 운영 매뉴얼
├── sessions/        세션 기록 (자동 생성)
├── projects/        프로젝트별 지식
├── decisions/       ADR (아키텍처 의사결정)
├── areas/           지속 관리 영역
├── resources/       참고 자료
├── daily-notes/     일일 노트
└── templates/       노트 템플릿 4종
```

### MCP (--with-mcp)

markdown-vault-mcp로 vault에 시맨틱 검색 제공:
- FastEmbed (ONNX, CPU-only) — API 키/GPU 불필요
- 하이브리드 검색 (키워드 + 시맨틱)
- headless Linux 서버에서도 동작

### Agent SDK 도구 (--with-sdk)

| 명령어 | 설명 |
|--------|------|
| `claude-review` | PR 자동 리뷰 (Opus + 구조화 출력) |
| `claude-scan` | 코드베이스 보안 스캔 (OWASP Top 10) |
| `claude-report` | 일일 코드 변경 요약 |

### Rules 템플릿

```bash
./init-project.sh cpp python    # 프로젝트에 .claude/rules/ 생성
```

## 구조

```
├── setup.sh                  원클릭 설치
├── init-project.sh           프로젝트별 rules/ 초기화
├── hooks/ (5개)              hook 스크립트
├── skills/ (7개)             skill 정의
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
