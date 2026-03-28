#!/bin/bash
# Claude Code 환경 부트스트랩
# 사용법: git clone <repo> && cd claude-code-config && ./setup.sh [--with-sdk]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
INSTALL_SDK=false

for arg in "$@"; do
  case "$arg" in
    --with-sdk) INSTALL_SDK=true ;;
    --help|-h)
      echo "사용법: ./setup.sh [옵션]"
      echo ""
      echo "옵션:"
      echo "  --with-sdk    Agent SDK 도구도 함께 설치 (Python 3.10+ 필요)"
      echo "  --help        이 도움말 표시"
      exit 0
      ;;
  esac
done

echo "=== Claude Code 환경 설정 ==="
echo ""

# 1. 필수 디렉토리 생성
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents"

# 2. hooks 복사 + 실행 권한
cp "$SCRIPT_DIR/hooks/"*.sh "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh
echo "✓ Hooks 설치 ($(ls "$SCRIPT_DIR/hooks/"*.sh | wc -l | tr -d ' ')개)"

# 3. skills 복사
for d in "$SCRIPT_DIR/skills/"/*/; do
  skill_name=$(basename "$d")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  cp "$d"SKILL.md "$CLAUDE_DIR/skills/$skill_name/"
done
echo "✓ Skills 설치 ($(ls -d "$SCRIPT_DIR/skills/"*/ | wc -l | tr -d ' ')개)"

# 4. settings.json 병합
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  if command -v jq &>/dev/null; then
    jq -s '.[0] * .[1]' "$CLAUDE_DIR/settings.json" "$SCRIPT_DIR/settings-template.json" \
      > "$CLAUDE_DIR/settings.json.tmp" \
      && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
    echo "✓ settings.json 병합 (기존 설정 보존)"
  else
    echo "⚠ jq 미설치 — settings.json 병합 건너뜀"
    echo "  수동: $SCRIPT_DIR/settings-template.json 참고"
  fi
else
  cp "$SCRIPT_DIR/settings-template.json" "$CLAUDE_DIR/settings.json"
  echo "✓ settings.json 생성"
fi

# 5. CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  echo "⚠ CLAUDE.md 이미 존재 — 템플릿: $SCRIPT_DIR/CLAUDE-template.md"
else
  cp "$SCRIPT_DIR/CLAUDE-template.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "✓ CLAUDE.md 생성"
fi

# 6. Agent SDK 도구 (옵션)
if [ "$INSTALL_SDK" = true ]; then
  echo ""
  echo "--- Agent SDK 도구 설치 ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. Agent SDK 설치를 건너뜁니다."
  else
    PYTHON_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    echo "  Python $PYTHON_VER 감지"

    SDK_DIR="$SCRIPT_DIR/agent-tools"
    if [ ! -d "$SDK_DIR" ]; then
      echo "✗ agent-tools/ 디렉토리가 없습니다."
    else
      cd "$SDK_DIR"
      python3 -m venv .venv
      source .venv/bin/activate
      pip install -e ".[dev]" --quiet
      echo "✓ Agent SDK 도구 설치 완료"
      echo "  활성화: source $SDK_DIR/.venv/bin/activate"
      echo "  명령어: claude-review, claude-scan, claude-report"
      deactivate
    fi
  fi
fi

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "사용법:"
echo "  새 Claude Code 세션 시작 → 자동 적용"
echo "  /guide                  → 설치된 기능 확인"
echo "  ./init-project.sh       → 프로젝트별 rules/ 초기화"
if [ "$INSTALL_SDK" = true ]; then
  echo "  source agent-tools/.venv/bin/activate → SDK 도구 활성화"
fi
