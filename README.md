# Claude Code Config

Claude Code 환경 설정을 한 번에 구성하는 도구 모음.

## 빠른 시작

```bash
git clone <repo-url> claude-code-config
cd claude-code-config
./setup.sh              # 기본 설정 (hooks, skills, settings)
./setup.sh --with-sdk   # + Agent SDK 도구 포함
```

## 포함된 기능

### Skills (6개)

| 스킬 | 설명 |
|------|------|
| `/debugit` | 체계적 디버깅 (가설 → 검증 → 수정 → 테스트) |
| `/review [PR]` | 코드 리뷰 (정확성/보안/성능/테스트) |
| `/perf` | 성능 분석 (프로파일링 → 병목 → 최적화) |
| `/prompt` | 프롬프트를 Task/Context/Req/Output 구조로 변환 |
| `/taskloop [이름]` | Boris 스타일 태스크 루프 (계획→승인→실행→교훈) |
| `/guide` | 설치된 기능 전체 가이드 |

### Hooks (4개)

| 훅 | 이벤트 | 설명 |
|----|--------|------|
| block-dangerous | PreToolUse (Bash) | rm -rf, git push --force 등 차단 |
| protect-sensitive | PreToolUse (Write/Edit) | .env, credentials 등 수정 차단 |
| auto-format | PostToolUse (Write/Edit) | black, clang-format, prettier 자동 적용 |
| notify-done | Stop | 작업 완료 알림 (macOS/Linux/Windows) |

### Agent SDK 도구 (--with-sdk)

| 명령어 | 설명 |
|--------|------|
| `claude-review` | PR 자동 리뷰 (Opus + 구조화 출력) |
| `claude-scan` | 코드베이스 보안 스캔 (OWASP Top 10) |
| `claude-report` | 일일 코드 변경 요약 |

### Rules 템플릿

프로젝트별 `.claude/rules/` 초기화:

```bash
# 현재 프로젝트 디렉토리에서 실행
~/claude-code-config/init-project.sh cpp python
```

제공 템플릿: `cpp.md`, `python.md`, `testing.md`

## 구조

```
├── setup.sh                  원클릭 글로벌 설치
├── init-project.sh           프로젝트별 rules/ 초기화
├── hooks/                    4개 hook 스크립트
├── skills/                   6개 skill 정의
├── rules-templates/          프로젝트 규칙 템플릿 (3개)
├── settings-template.json    hooks 설정
├── CLAUDE-template.md        CLAUDE.md 템플릿
└── agent-tools/              Agent SDK Python 프로젝트
    ├── pyproject.toml
    ├── src/claude_tools/
    └── tests/
```

## 요구사항

- Claude Code v2.1.32+
- `jq` (settings.json 병합용, 선택)
- Python 3.10+ (--with-sdk 사용 시)
- `gh` CLI (PR 리뷰용, 선택)
