#!/bin/bash
# Codex CLI 환경 부트스트랩. Claude 전용 설정은 건드리지 않는다.
# 사용법: ./setup-codex.sh [--with-vault] [--with-mcp] [--with-hooks] [--all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
SKILLS_DIR="$AGENTS_DIR/skills"
INSTALL_DIR="$CODEX_DIR/pimp-my-codex"
VAULT_DIR="${PIMP_MY_VAULT_DIR:-${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}}"
INSTALL_VAULT=false
INSTALL_MCP=false
INSTALL_HOOKS=false
FORCE_AGENTS=false

usage() {
  cat <<'EOF'
Usage: ./setup-codex.sh [options]

Options:
  --with-vault       Create or update the shared knowledge vault
  --with-mcp         Install the local vault semantic-search MCP server
  --with-hooks       Install optional Codex lifecycle hooks (review with /hooks)
  --all              Enable vault, MCP, and hooks
  --force-agents     Replace ~/.codex/AGENTS.md after making a .bak copy
  -h, --help         Show this help

Environment:
  PIMP_MY_VAULT_DIR  Vault path (default: ~/Documents/vault)
  CODEX_HOME         Codex config path (default: ~/.codex)
  AGENTS_HOME        Agent skills path parent (default: ~/.agents)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --with-vault) INSTALL_VAULT=true ;;
    --with-mcp) INSTALL_MCP=true ;;
    --with-hooks) INSTALL_HOOKS=true ;;
    --all) INSTALL_VAULT=true; INSTALL_MCP=true; INSTALL_HOOKS=true ;;
    --force-agents) FORCE_AGENTS=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

echo "=== Codex setup ==="
mkdir -p "$CODEX_DIR" "$SKILLS_DIR"

# Codex uses standard SKILL.md metadata. These workflows do not depend on
# Claude-only agents, slash-command argument substitution, or Claude settings.
CODEX_SKILLS=(
  debugit review perf prompt plain-words
  vault-note vault-save vault-recall vault-search vault-daily vault-distill
)
for skill in "${CODEX_SKILLS[@]}"; do
  src="$SCRIPT_DIR/skills/$skill"
  dest="$SKILLS_DIR/$skill"
  mkdir -p "$dest"
  if [ -d "$src/scripts" ]; then
    mkdir -p "$dest/scripts"
    cp -R "$src/scripts/." "$dest/scripts/"
  fi
  # Claude-specific frontmatter is not part of the Agent Skills format.
  awk '
    NR == 1 && $0 == "---" { frontmatter = 1 }
    frontmatter && /^(allowed-tools|argument-hint|effort):/ { next }
    { print }
    frontmatter && NR > 1 && $0 == "---" { frontmatter = 0 }
  ' "$src/SKILL.md" \
    | sed \
      -e 's/\$ARGUMENTS/the user\x27s supplied arguments/g' \
      -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
      -e 's#/vault-#\$vault-#g' \
      -e 's#/plain-words#\$plain-words#g' \
      -e 's#/review#\$review#g' \
      -e 's#- 변경사항: !`.*#- 변경사항: PR 번호가 있으면 `gh pr diff <번호>`로, 없으면 `git diff`로 확인한다.#' \
      -e 's#- PR 설명: !`.*#- PR 번호가 있으면 `gh pr view <번호>`로 의도와 설명을 확인한다.#' \
    > "$dest/SKILL.md"
done
echo "✓ Codex skills installed (${#CODEX_SKILLS[@]}) → $SKILLS_DIR"

AGENTS_DEST="$CODEX_DIR/AGENTS.md"
if [ -f "$AGENTS_DEST" ] && [ "$FORCE_AGENTS" = false ]; then
  echo "⚠ Existing AGENTS.md preserved — template: $SCRIPT_DIR/codex/AGENTS.md"
elif [ -f "$AGENTS_DEST" ]; then
  cp "$AGENTS_DEST" "$AGENTS_DEST.bak"
  cp "$SCRIPT_DIR/codex/AGENTS.md" "$AGENTS_DEST"
  echo "✓ AGENTS.md replaced (backup: $AGENTS_DEST.bak)"
else
  cp "$SCRIPT_DIR/codex/AGENTS.md" "$AGENTS_DEST"
  echo "✓ Global Codex guidance installed"
fi

if [ "$INSTALL_VAULT" = true ]; then
  if [ -d "$VAULT_DIR" ] && [ "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]; then
    mkdir -p "$VAULT_DIR/templates"
    cp "$SCRIPT_DIR/vault-template/templates/"*.md "$VAULT_DIR/templates/"
    echo "✓ Existing vault templates updated: $VAULT_DIR"
  else
    mkdir -p "$VAULT_DIR"
    cp -R "$SCRIPT_DIR/vault-template/." "$VAULT_DIR/"
    git -C "$VAULT_DIR" init --quiet
    git -C "$VAULT_DIR" add -A
    git -C "$VAULT_DIR" commit -m "Initial vault structure" --quiet || true
    echo "✓ Vault created: $VAULT_DIR"
  fi
fi

if [ "$INSTALL_MCP" = true ]; then
  if ! command -v python3 >/dev/null; then
    echo "✗ python3 is required for the vault MCP server" >&2
  else
    MCP_DIR="$SCRIPT_DIR/mcp"
    VENV_DIR="$MCP_DIR/.venv"
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install -q -r "$MCP_DIR/requirements.txt"
    codex mcp remove vault >/dev/null 2>&1 || true
    codex mcp add vault --env "PIMP_MY_VAULT_DIR=$VAULT_DIR" -- \
      "$VENV_DIR/bin/python" "$MCP_DIR/server.py"
    echo "✓ Vault MCP registered for Codex"
  fi
fi

if [ "$INSTALL_HOOKS" = true ]; then
  if ! command -v jq >/dev/null; then
    echo "⚠ jq is required to merge hooks; install it and re-run --with-hooks" >&2
  else
    mkdir -p "$INSTALL_DIR/hooks"
    for hook in vault-briefing prompt-hint plain-words-remind block-dangerous notify-done; do
      sed \
        -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
        -e 's/CLAUDE_CONFIG_REVIEW_DAYS/PIMP_MY_CONFIG_REVIEW_DAYS/g' \
        -e 's/CLAUDE_CONFIG_DIR/CODEX_CONFIG_DIR/g' \
        -e 's#\.claude#\.codex#g' \
        -e 's/Claude Code/Codex/g' \
        "$SCRIPT_DIR/hooks/$hook.sh" > "$INSTALL_DIR/hooks/$hook.sh"
      chmod +x "$INSTALL_DIR/hooks/$hook.sh"
    done
    rendered_hooks="$(mktemp "$CODEX_DIR/hooks.XXXXXX")"
    merged_hooks="$(mktemp "$CODEX_DIR/hooks-merged.XXXXXX")"
    sed "s|{{CODEX_INSTALL_DIR}}|$INSTALL_DIR|g" "$SCRIPT_DIR/codex/hooks.json" > "$rendered_hooks"
    if [ -f "$CODEX_DIR/hooks.json" ]; then
      jq -s '.[0] * {hooks: ((.[0].hooks // {}) * (.[1].hooks // {}))}' \
        "$CODEX_DIR/hooks.json" "$rendered_hooks" > "$merged_hooks"
    else
      cp "$rendered_hooks" "$merged_hooks"
    fi
    mv "$merged_hooks" "$CODEX_DIR/hooks.json"
    rm -f "$rendered_hooks"
    echo "✓ Optional hooks merged — review and trust them with /hooks"
  fi
fi

echo
echo "=== Codex setup complete ==="
echo 'Start a new Codex session, then use $guide or mention a workflow with $skill-name.'
echo "For a shared vault outside the default path, export PIMP_MY_VAULT_DIR before starting Codex."
