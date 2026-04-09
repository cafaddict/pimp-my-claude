#!/bin/bash
# Claude Code 환경 부트스트랩
# 사용법: git clone <repo> && cd pimp-my-claude && ./setup.sh [옵션]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
INSTALL_SDK=false
INSTALL_VAULT=false
INSTALL_MCP=false
FORCE_CLAUDE_MD=false
VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"

for arg in "$@"; do
  case "$arg" in
    --with-sdk)   INSTALL_SDK=true ;;
    --with-vault) INSTALL_VAULT=true ;;
    --with-mcp)   INSTALL_MCP=true ;;
    --all)        INSTALL_SDK=true; INSTALL_VAULT=true; INSTALL_MCP=true ;;
    --force-claude-md) FORCE_CLAUDE_MD=true ;;
    --help|-h)
      echo "사용법: ./setup.sh [옵션]"
      echo ""
      echo "옵션:"
      echo "  --with-sdk         Agent SDK 도구 설치 (Python 3.10+ 필요)"
      echo "  --with-vault       Obsidian vault 구조 생성"
      echo "  --with-mcp         MCP 시맨틱 검색 서버 설치 (fastembed + sqlite-vec)"
      echo "  --all              위 3개 전부 설치"
      echo "  --force-claude-md  CLAUDE.md 덮어쓰기 (기존 백업 후 교체)"
      echo "  --help             이 도움말 표시"
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
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules"

# 2. hooks 복사 + 실행 권한
cp "$SCRIPT_DIR/hooks/"*.sh "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh
echo "✓ Hooks 설치 ($(ls "$SCRIPT_DIR/hooks/"*.sh | wc -l | tr -d ' ')개)"

# 3. skills 복사
for d in "$SCRIPT_DIR/skills/"/*/; do
  skill_name=$(basename "$d")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  sed "s|{{REPO_DIR}}|$SCRIPT_DIR|g" "$d"SKILL.md > "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done
echo "✓ Skills 설치 ($(ls -d "$SCRIPT_DIR/skills/"*/ | wc -l | tr -d ' ')개)"

# 3-1. agents 복사
if [ -d "$SCRIPT_DIR/agents/" ] && ls "$SCRIPT_DIR/agents/"*.md &>/dev/null; then
  cp "$SCRIPT_DIR/agents/"*.md "$CLAUDE_DIR/agents/"
  echo "✓ Agents 설치 ($(ls "$SCRIPT_DIR/agents/"*.md | wc -l | tr -d ' ')개)"
fi

# 3-2. global rules 복사 (vault-notes 등)
if ls "$SCRIPT_DIR/rules-templates/vault-notes.md" &>/dev/null; then
  cp "$SCRIPT_DIR/rules-templates/vault-notes.md" "$CLAUDE_DIR/rules/"
  echo "✓ Global rules 설치 (vault-notes)"
fi

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
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ "$FORCE_CLAUDE_MD" = false ]; then
  echo "⚠ CLAUDE.md 이미 존재 — 템플릿: $SCRIPT_DIR/CLAUDE-template.md (--force-claude-md 로 덮어쓰기)"
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ "$FORCE_CLAUDE_MD" = true ]; then
  cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
  sed "s|{{REPO_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/CLAUDE-template.md" > "$CLAUDE_DIR/CLAUDE.md"
  echo "✓ CLAUDE.md 덮어쓰기 (백업: CLAUDE.md.bak)"
else
  sed "s|{{REPO_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/CLAUDE-template.md" > "$CLAUDE_DIR/CLAUDE.md"
  echo "✓ CLAUDE.md 생성"
fi

# 6. Vault 구조 생성 (옵션)
if [ "$INSTALL_VAULT" = true ]; then
  echo ""
  echo "--- Vault 구조 생성 ---"
  if [ -d "$VAULT_DIR" ] && [ "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]; then
    echo "⚠ $VAULT_DIR 이미 존재 — 구조 건너뜀, 템플릿/CLAUDE.md 업데이트"
    # 기존 vault: 템플릿만 업데이트 (기존 노트는 건드리지 않음)
    if [ -d "$VAULT_DIR/templates" ]; then
      cp "$SCRIPT_DIR/vault-template/templates/"*.md "$VAULT_DIR/templates/"
      echo "  ✓ Vault 템플릿 업데이트"
    fi
    if [ -f "$VAULT_DIR/CLAUDE.md" ]; then
      cp "$VAULT_DIR/CLAUDE.md" "$VAULT_DIR/CLAUDE.md.bak"
      cp "$SCRIPT_DIR/vault-template/CLAUDE.md" "$VAULT_DIR/CLAUDE.md"
      echo "  ✓ Vault CLAUDE.md 업데이트 (백업: CLAUDE.md.bak)"
    fi
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

  # vault 경로를 settings.json에 주입 (additionalDirectories + env)
  if command -v jq &>/dev/null && [ -f "$CLAUDE_DIR/settings.json" ]; then
    VAULT_TILDE="${VAULT_DIR/#$HOME/\~}"

    # permissions.additionalDirectories에 vault 경로 추가
    if ! jq -e ".permissions.additionalDirectories // [] | index(\"$VAULT_TILDE\")" "$CLAUDE_DIR/settings.json" &>/dev/null; then
      jq ".permissions.additionalDirectories = ((.permissions.additionalDirectories // []) + [\"$VAULT_TILDE\"])" \
        "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" \
        && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
      echo "✓ vault 경로 → settings.json additionalDirectories 추가"
    fi

    # env.CLAUDE_VAULT_DIR 주입 (Claude Code 세션에서 확실히 인식하도록)
    CURRENT_ENV_VAULT=$(jq -r '.env.CLAUDE_VAULT_DIR // empty' "$CLAUDE_DIR/settings.json")
    if [ "$CURRENT_ENV_VAULT" != "$VAULT_DIR" ]; then
      jq ".env.CLAUDE_VAULT_DIR = \"$VAULT_DIR\"" \
        "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" \
        && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
      echo "✓ CLAUDE_VAULT_DIR → settings.json env 추가"
    fi
  fi
fi

# 7. MCP 시맨틱 검색 서버 (옵션)
if [ "$INSTALL_MCP" = true ]; then
  echo ""
  echo "--- MCP 시맨틱 검색 서버 설치 ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. MCP 설치를 건너뜁니다."
  else
    MCP_DIR="$SCRIPT_DIR/mcp"
    VENV_DIR="$MCP_DIR/.venv"

    if [ ! -d "$VENV_DIR" ]; then
      python3 -m venv "$VENV_DIR"
      echo "  Python venv 생성"
    fi

    "$VENV_DIR/bin/pip" install -q -r "$MCP_DIR/requirements.txt"
    echo "✓ Dependencies 설치 완료"

    # 임베딩 모델 사전 다운로드 (~220MB)
    "$VENV_DIR/bin/python" -c "from fastembed import TextEmbedding; TextEmbedding(model_name='sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')" 2>/dev/null
    echo "✓ Embedding 모델 다운로드 완료 (paraphrase-multilingual-MiniLM-L12-v2)"

    # Claude Code MCP 등록
    if command -v claude &>/dev/null; then
      claude mcp remove vault 2>/dev/null || true
      claude mcp add vault -s user \
        -e CLAUDE_VAULT_DIR="$VAULT_DIR" \
        -- "$VENV_DIR/bin/python" "$MCP_DIR/server.py"
      echo "✓ MCP 서버 등록: vault (user scope — 모든 프로젝트에서 사용 가능)"
    else
      echo "⚠ claude CLI 미설치 — MCP 수동 등록 필요:"
      echo "  claude mcp add vault -s user -e CLAUDE_VAULT_DIR=$VAULT_DIR -- $VENV_DIR/bin/python $MCP_DIR/server.py"
    fi

    echo "  (첫 검색 시 자동 인덱싱 ~15초)"
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
  echo "  /vault-recall [키워드]  → 이전 세션 컨텍스트 복원"
fi
if [ "$INSTALL_SDK" = true ]; then
  echo "  source agent-tools/.venv/bin/activate → SDK 도구 활성화"
fi
