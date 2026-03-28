#!/bin/bash
# Claude Code 환경 부트스트랩
# 사용법: git clone <repo> && cd claude-code-config && ./setup.sh [옵션]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
INSTALL_SDK=false
INSTALL_VAULT=false
INSTALL_MCP=false
VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"

for arg in "$@"; do
  case "$arg" in
    --with-sdk)   INSTALL_SDK=true ;;
    --with-vault) INSTALL_VAULT=true ;;
    --with-mcp)   INSTALL_MCP=true ;;
    --all)        INSTALL_SDK=true; INSTALL_VAULT=true; INSTALL_MCP=true ;;
    --help|-h)
      echo "사용법: ./setup.sh [옵션]"
      echo ""
      echo "옵션:"
      echo "  --with-sdk    Agent SDK 도구 설치 (Python 3.10+ 필요)"
      echo "  --with-vault  Obsidian vault 구조 생성"
      echo "  --with-mcp    markdown-vault-mcp 설치 + Claude Code MCP 등록"
      echo "  --all         위 3개 전부 설치"
      echo "  --help        이 도움말 표시"
      echo ""
      echo "환경변수:"
      echo "  CLAUDE_VAULT_DIR  vault 경로 (기본: ~/Documents/vault)"
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

# 6. Vault 구조 생성 (옵션)
if [ "$INSTALL_VAULT" = true ]; then
  echo ""
  echo "--- Vault 구조 생성 ---"
  if [ -d "$VAULT_DIR" ] && [ "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]; then
    echo "⚠ $VAULT_DIR 이미 존재하고 비어있지 않음 — 건너뜀"
  else
    mkdir -p "$VAULT_DIR"
    cp -r "$SCRIPT_DIR/vault-template/"* "$VAULT_DIR/"
    cp "$SCRIPT_DIR/vault-template/.gitignore" "$VAULT_DIR/"
    cd "$VAULT_DIR" && git init && git add -A && git commit -m "Initial vault structure" --quiet
    echo "✓ Vault 생성: $VAULT_DIR"
  fi

  # CLAUDE_VAULT_DIR을 쉘 rc에 등록 (기본값과 다를 때만)
  if [ "$VAULT_DIR" != "$HOME/Documents/vault" ] || ! grep -q "CLAUDE_VAULT_DIR" "${SHELL_RC:-$HOME/.zshrc}" 2>/dev/null; then
    SHELL_RC="$HOME/.$(basename "${SHELL:-zsh}")rc"
    if ! grep -q "CLAUDE_VAULT_DIR" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# Claude Code vault path" >> "$SHELL_RC"
      echo "export CLAUDE_VAULT_DIR=\"$VAULT_DIR\"" >> "$SHELL_RC"
      echo "✓ CLAUDE_VAULT_DIR=$VAULT_DIR → $SHELL_RC 에 추가"
    fi
  fi
fi

# 7. MCP 연동 (옵션)
if [ "$INSTALL_MCP" = true ]; then
  echo ""
  echo "--- MCP 연동 (markdown-vault-mcp) ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. MCP 설치를 건너뜁니다."
  else
    # vault venv에 설치
    MCP_VENV="$VAULT_DIR/.venv"
    if [ ! -d "$MCP_VENV" ]; then
      python3 -m venv "$MCP_VENV"
    fi
    "$MCP_VENV/bin/pip" install "markdown-vault-mcp[all]" --quiet
    echo "✓ markdown-vault-mcp 설치 완료"

    # Claude Code MCP 등록
    if command -v claude &>/dev/null; then
      claude mcp remove vault 2>/dev/null || true
      claude mcp add vault \
        -e "MARKDOWN_VAULT_MCP_SOURCE_DIR=$VAULT_DIR" \
        -e "EMBEDDING_PROVIDER=fastembed" \
        -- "$MCP_VENV/bin/markdown-vault-mcp" serve
      echo "✓ Claude Code MCP 등록 완료"
    else
      echo "⚠ claude CLI 미설치 — MCP 수동 등록 필요:"
      echo "  claude mcp add vault -e MARKDOWN_VAULT_MCP_SOURCE_DIR=$VAULT_DIR -e EMBEDDING_PROVIDER=fastembed -- $MCP_VENV/bin/markdown-vault-mcp serve"
    fi
  fi
fi

# 8. Agent SDK 도구 (옵션)
if [ "$INSTALL_SDK" = true ]; then
  echo ""
  echo "--- Agent SDK 도구 설치 ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. Agent SDK 설치를 건너뜁니다."
  else
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
if [ "$INSTALL_VAULT" = true ]; then
  echo "  /recall [키워드]        → 이전 세션 컨텍스트 복원"
fi
if [ "$INSTALL_SDK" = true ]; then
  echo "  source agent-tools/.venv/bin/activate → SDK 도구 활성화"
fi
