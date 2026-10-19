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
UPGRADE_HOOKS=false
DRY_RUN=false
CODEX_HOOKS=(plain-words-remind block-dangerous notify-done)
# No longer shipped. Installed files stay; only --upgrade-hooks unbinds them.
CODEX_RETIRED_HOOKS=(prompt-hint)

usage() {
  cat <<'EOF'
Usage: ./setup-codex.sh [options]

Options:
  --with-vault       Create or update the shared knowledge vault
  --with-mcp         Install the local vault semantic-search MCP server
  --with-hooks       Install optional writing, safety, and completion hooks (review with /hooks)
  --all              Enable vault, MCP, and hooks
  --force-agents     Replace ~/.codex/AGENTS.md after making a .bak copy
  --upgrade-hooks    Only update installed hook definitions and scripts to this version:
                     prints a diff, backs up, then applies. Edited ones are kept and reported.
  --dry-run          With --upgrade-hooks: show the changes, write nothing
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
    --upgrade-hooks) UPGRADE_HOOKS=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$DRY_RUN" = true ] && [ "$UPGRADE_HOOKS" = false ]; then
  echo "--dry-run only works with --upgrade-hooks" >&2
  exit 2
fi

# shellcheck source=lib/install-lib.sh
source "$SCRIPT_DIR/lib/install-lib.sh"
INSTALL_DIR_REPL="$(pimp_sed_repl "$INSTALL_DIR")"

# Checked before anything is written; any failure leaves every file as it was.
# Hook commands and code lines in the skills use these paths unquoted.
for path in "$INSTALL_DIR" "$SKILLS_DIR"; do
  [ "$UPGRADE_HOOKS" = true ] && [ "$path" = "$SKILLS_DIR" ] && continue
  if ! pimp_shell_safe_path "$path"; then
    echo "✗ Path contains spaces or shell metacharacters: $path" >&2
    echo "  Rendered hook and skill commands use it unquoted, so nothing was installed." >&2
    echo "  Set CODEX_HOME / AGENTS_HOME to a path without them and re-run." >&2
    exit 2
  fi
done
if [ "$INSTALL_HOOKS" = true ] || [ "$UPGRADE_HOOKS" = true ]; then
  if [ -L "$CODEX_DIR/hooks.json" ]; then
    echo "✗ $CODEX_DIR/hooks.json is a symlink ($(readlink "$CODEX_DIR/hooks.json")); nothing was changed." >&2
    echo "  Edit the link target yourself (template: $SCRIPT_DIR/codex/hooks.json)." >&2
    exit 1
  fi
  if [ -f "$CODEX_DIR/hooks.json" ] && command -v jq >/dev/null; then
    if ! jq empty "$CODEX_DIR/hooks.json" 2>/dev/null; then
      echo "✗ $CODEX_DIR/hooks.json is not valid JSON; nothing was changed." >&2
      exit 1
    fi
    if ! pimp_hooks_readable "$CODEX_DIR/hooks.json" "$SCRIPT_DIR/codex/hooks.json"; then
      echo "✗ Could not read the hook structure in $CODEX_DIR/hooks.json; nothing was changed." >&2
      exit 1
    fi
  fi
fi

render_codex_hook() {
  sed \
    -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
    -e 's/CLAUDE_CONFIG_REVIEW_DAYS/PIMP_MY_CONFIG_REVIEW_DAYS/g' \
    -e 's/CLAUDE_CONFIG_DIR/CODEX_CONFIG_DIR/g' \
    -e 's#\.claude#\.codex#g' \
    -e 's/Claude Code/Codex/g'
}
render_codex_hooks_json() { sed "s|{{CODEX_INSTALL_DIR}}|$INSTALL_DIR_REPL|g"; }

# Install or merge the optional hooks. Default: add what is missing, keep existing
# definitions and scripts. --upgrade-hooks: also replace definitions and scripts that
# match a version we shipped, and unbind retired hooks; edited ones are reported.
install_hooks() {
  local mode=merge work hook dest changed=false known='[]' retired name
  local install=() replace=() pending=() held=()
  [ "$UPGRADE_HOOKS" = true ] && mode=upgrade
  if ! command -v jq >/dev/null; then
    echo "⚠ jq is required to merge hooks; install it and re-run --with-hooks" >&2
    [ "$mode" = upgrade ] && exit 1
    return 0
  fi
  if [ -f "$CODEX_DIR/hooks.json" ] && ! jq empty "$CODEX_DIR/hooks.json" 2>/dev/null; then
    echo "✗ $CODEX_DIR/hooks.json is not valid JSON; nothing was changed." >&2
    exit 1
  fi
  work="$(mktemp -d "${TMPDIR:-/tmp}/pimp-codex-hooks.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  for hook in "${CODEX_HOOKS[@]}"; do
    render_codex_hook < "$SCRIPT_DIR/hooks/$hook.sh" > "$work/$hook.sh"
    dest="$INSTALL_DIR/hooks/$hook.sh"
    case "$(pimp_classify "$work/$hook.sh" "$dest" "hooks/$hook.sh" render_codex_hook)" in
      missing) install+=("$hook") ;;
      shipped) if [ "$mode" = upgrade ]; then replace+=("$hook"); else pending+=("$hook"); fi ;;
      modified) held+=("$hook") ;;
    esac
  done

  render_codex_hooks_json < "$SCRIPT_DIR/codex/hooks.json" > "$work/template.json"
  retired="$(for name in "${CODEX_RETIRED_HOOKS[@]}"; do printf '%s/hooks/%s.sh\n' "$INSTALL_DIR" "$name"; done | jq -R . | jq -s .)"
  if [ -f "$CODEX_DIR/hooks.json" ]; then
    [ "$mode" = upgrade ] && known="$(pimp_known_handlers codex/hooks.json render_codex_hooks_json)"
    if ! pimp_merge_hooks "$CODEX_DIR/hooks.json" "$work/template.json" "$mode" "$known" "$retired" \
        "$work/hooks.json" "$work/report.json"; then
      echo "✗ Could not read the hook structure in $CODEX_DIR/hooks.json; nothing was changed." >&2
      exit 1
    fi
    pimp_same_json "$CODEX_DIR/hooks.json" "$work/hooks.json" || changed=true
    pimp_print_report "$work/report.json"
    if [ "$changed" = true ] && [ "$mode" = upgrade ]; then
      diff -u "$CODEX_DIR/hooks.json" "$work/hooks.json" || true
    fi
  else
    cp "$work/template.json" "$work/hooks.json"
    changed=true
  fi
  for hook in ${replace[@]+"${replace[@]}"}; do
    echo "hook script update: $INSTALL_DIR/hooks/$hook.sh"
    diff -u "$INSTALL_DIR/hooks/$hook.sh" "$work/$hook.sh" || true
  done
  for hook in ${held[@]+"${held[@]}"}; do
    echo "⚠ Kept edited hook script: $INSTALL_DIR/hooks/$hook.sh (compare with the repository version before replacing it)"
  done
  if [ "${#pending[@]}" -gt 0 ]; then
    echo "⚠ ${#pending[@]} installed hook script(s) have a newer version — review: ./setup-codex.sh --upgrade-hooks --dry-run"
  fi

  if [ "$changed" = false ] && [ "${#install[@]}" -eq 0 ] && [ "${#replace[@]}" -eq 0 ]; then
    echo "✓ Hooks unchanged"
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "(--dry-run) Nothing was changed."
    return 0
  fi

  local backup="" restore=""
  if [ "${#replace[@]}" -gt 0 ] || { [ "$changed" = true ] && [ -f "$CODEX_DIR/hooks.json" ]; }; then
    backup="$(pimp_new_backup_dir "$INSTALL_DIR/backups")"
    restore="$backup/restore-commands.txt"
    echo "# pimp-my-codex hook backup. Run these commands to undo this run." > "$restore"
    if [ "$changed" = true ] && [ -f "$CODEX_DIR/hooks.json" ]; then
      cp -p "$CODEX_DIR/hooks.json" "$backup/hooks.json"
      printf 'cp -p %q %q\n' "$backup/hooks.json" "$CODEX_DIR/hooks.json" >> "$restore"
    fi
    for hook in ${replace[@]+"${replace[@]}"}; do
      mkdir -p "$backup/hooks"
      cp -p "$INSTALL_DIR/hooks/$hook.sh" "$backup/hooks/$hook.sh"
      printf 'cp -p %q %q\n' "$backup/hooks/$hook.sh" "$INSTALL_DIR/hooks/$hook.sh" >> "$restore"
    done
  fi
  mkdir -p "$INSTALL_DIR/hooks"
  for hook in ${install[@]+"${install[@]}"} ${replace[@]+"${replace[@]}"}; do
    pimp_install_file "$work/$hook.sh" "$INSTALL_DIR/hooks/$hook.sh" 755
  done
  if [ "$changed" = true ]; then
    pimp_install_file "$work/hooks.json" "$CODEX_DIR/hooks.json" 644
  fi
  echo "✓ Optional hooks merged without replacing existing handlers — review and trust them with /hooks"
  if [ -n "$backup" ]; then
    echo "  Backup: $backup — undo with the commands in $restore"
  fi
  echo "  Installed hook script files are never deleted."
}

if [ "$UPGRADE_HOOKS" = true ]; then
  echo "=== Codex hooks upgrade ==="
  install_hooks
  exit 0
fi

echo "=== Codex setup ==="
mkdir -p "$CODEX_DIR" "$SKILLS_DIR"
mkdir -p "$INSTALL_DIR/bin"
case "$(pimp_classify "$SCRIPT_DIR/bin/vault-sync.sh" "$INSTALL_DIR/bin/vault-sync.sh" bin/vault-sync.sh)" in
  current) ;;
  modified) echo "⚠ Kept edited $INSTALL_DIR/bin/vault-sync.sh (not overwritten)" ;;
  *) pimp_install_file "$SCRIPT_DIR/bin/vault-sync.sh" "$INSTALL_DIR/bin/vault-sync.sh" 755 ;;
esac

# Codex uses standard SKILL.md metadata. These workflows do not depend on
# Claude-only agents, slash-command argument substitution, or Claude settings.
CODEX_SKILLS=(
  debugit review perf prompt plain-words
  vault-note vault-save vault-recall vault-search vault-daily vault-distill
)
SKILLS_DIR_REPL="$(pimp_sed_repl "$SKILLS_DIR")"
# Claude-specific frontmatter is not part of the Agent Skills format.
# Paths stay as placeholders while slash commands become `$skill` names, so a path
# such as .../skills/plain-words/... or a home directory under /review/ is never
# rewritten. Slash commands are rewritten only after a line start, space, backtick, or '('.
render_codex_skill() {
  awk '
    NR == 1 && $0 == "---" { frontmatter = 1 }
    frontmatter && /^(allowed-tools|argument-hint|effort):/ { next }
    { print }
    frontmatter && NR > 1 && $0 == "---" { frontmatter = 0 }
  ' \
    | sed \
      -e 's|{{REPO_DIR}}/skills/plain-words|__PIMP_SKILLS_DIR__/plain-words|g' \
      -e 's|{{REPO_DIR}}|__PIMP_INSTALL_DIR__|g' \
      -e 's/\$ARGUMENTS/the user\x27s supplied arguments/g' \
      -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
      -e 's#- 변경사항: !`.*#- 변경사항: PR 번호가 있으면 `gh pr diff <번호>`로, 없으면 `git diff`로 확인한다.#' \
      -e 's#- PR 설명: !`.*#- PR 번호가 있으면 `gh pr view <번호>`로 의도와 설명을 확인한다.#' \
    | sed -E 's#(^|[[:space:]`(])/(vault-|plain-words|review)#\1$\2#g' \
    | sed \
      -e "s|__PIMP_SKILLS_DIR__|$SKILLS_DIR_REPL|g" \
      -e "s|__PIMP_INSTALL_DIR__|$INSTALL_DIR_REPL|g"
}
# Earlier installers rendered SKILL.md differently (a3e60f6 and b6a362d). They are kept
# only to recognise copies those versions installed, so those can be updated.
render_codex_skill_a3e60f6() {
  awk '
    NR == 1 && $0 == "---" { frontmatter = 1 }
    frontmatter && /^(allowed-tools|argument-hint|effort):/ { next }
    { print }
    frontmatter && NR > 1 && $0 == "---" { frontmatter = 0 }
  ' \
    | sed \
      -e 's/\$ARGUMENTS/the user\x27s supplied arguments/g' \
      -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
      -e 's#/vault-#\$vault-#g' \
      -e 's#/plain-words#\$plain-words#g' \
      -e 's#/review#\$review#g' \
      -e 's#- 변경사항: !`.*#- 변경사항: PR 번호가 있으면 `gh pr diff <번호>`로, 없으면 `git diff`로 확인한다.#' \
      -e 's#- PR 설명: !`.*#- PR 번호가 있으면 `gh pr view <번호>`로 의도와 설명을 확인한다.#'
}
render_codex_skill_b6a362d() {
  awk '
    NR == 1 && $0 == "---" { frontmatter = 1 }
    frontmatter && /^(allowed-tools|argument-hint|effort):/ { next }
    { print }
    frontmatter && NR > 1 && $0 == "---" { frontmatter = 0 }
  ' \
    | sed \
      -e "s|{{REPO_DIR}}|$INSTALL_DIR|g" \
      -e "s|$INSTALL_DIR/skills/plain-words|$SKILLS_DIR/plain-words|g" \
      -e 's|/bin/vault-sync|__PIMP_MY_VAULT_SYNC__|g' \
      -e 's/\$ARGUMENTS/the user\x27s supplied arguments/g' \
      -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' \
      -e 's#/vault-#\$vault-#g' \
      -e 's#/plain-words#\$plain-words#g' \
      -e 's#/review#\$review#g' \
      -e 's|__PIMP_MY_VAULT_SYNC__|/bin/vault-sync|g' \
      -e 's#- 변경사항: !`.*#- 변경사항: PR 번호가 있으면 `gh pr diff <번호>`로, 없으면 `git diff`로 확인한다.#' \
      -e 's#- PR 설명: !`.*#- PR 번호가 있으면 `gh pr view <번호>`로 의도와 설명을 확인한다.#'
}

# Same rule as the Claude installer: a copy is replaced only when it is missing or equals
# a version this repository installed. Anything else (your edits, or a copy whose origin
# cannot be told) is kept and listed. Files you added to a skill folder are never touched.
SKILL_WORK="$(mktemp -d "${TMPDIR:-/tmp}/pimp-codex-skills.XXXXXX")"
# shellcheck disable=SC2064
trap "rm -rf '$SKILL_WORK'" EXIT
SKILL_HELD=()
SKILL_WRITTEN=0
# install_skill_file <new-file> <dest> <repo-path> <mode> <render...>
install_skill_file() {
  local new="$1" dest="$2" path="$3" mode="$4" state render
  shift 4
  state="$(pimp_classify "$new" "$dest" "$path" "$1")"
  if [ "$state" = modified ] && [ -f "$dest" ] && [ ! -L "$dest" ]; then
    for render in "${@:2}"; do
      pimp_was_shipped "$path" "$dest" "$render" && { state=shipped; break; }
    done
  fi
  case "$state" in
    missing|shipped)
      mkdir -p "$(dirname "$dest")"
      pimp_install_file "$new" "$dest" "$mode"
      SKILL_WRITTEN=$((SKILL_WRITTEN + 1))
      ;;
    modified) SKILL_HELD+=("$dest") ;;
  esac
}
for skill in "${CODEX_SKILLS[@]}"; do
  src="$SCRIPT_DIR/skills/$skill"
  render_codex_skill < "$src/SKILL.md" > "$SKILL_WORK/$skill.md"
  install_skill_file "$SKILL_WORK/$skill.md" "$SKILLS_DIR/$skill/SKILL.md" "skills/$skill/SKILL.md" 644 \
    render_codex_skill render_codex_skill_b6a362d render_codex_skill_a3e60f6
  if [ -d "$src/scripts" ]; then
    while IFS= read -r rel; do
      mode=644
      [ -x "$src/scripts/$rel" ] && mode=755
      install_skill_file "$src/scripts/$rel" "$SKILLS_DIR/$skill/scripts/$rel" "skills/$skill/scripts/$rel" "$mode" cat
    done < <(cd "$src/scripts" && find . -type f | sed 's|^\./||' | sort)
  fi
done
rm -rf "$SKILL_WORK"
echo "✓ Codex skills (${#CODEX_SKILLS[@]}) → $SKILLS_DIR: $SKILL_WRITTEN file(s) installed or updated"
if [ "${#SKILL_HELD[@]}" -gt 0 ]; then
  echo "⚠ Kept ${#SKILL_HELD[@]} skill file(s) that match no version this repository installed"
  echo "  (your edits, or an install whose origin cannot be determined — not overwritten):"
  for f in "${SKILL_HELD[@]}"; do echo "    $f"; done
  echo "  To take the repository version of one file: mv <file> <file>.mine && ./setup-codex.sh"
  echo "  Compare: diff -u <file>.mine <file>    Undo: mv <file>.mine <file>"
fi

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
    if ! git -C "$VAULT_DIR" commit -m "Initial vault structure" --quiet; then
      echo "✗ Initial vault commit failed — configure git user.name/user.email, then run setup again." >&2
      exit 1
    fi
    echo "✓ Vault created and initial commit recorded: $VAULT_DIR"
  fi
fi

if [ "$INSTALL_MCP" = true ]; then
  if ! command -v python3 >/dev/null; then
    echo "✗ python3 is required for the vault MCP server" >&2
  elif ! command -v codex >/dev/null; then
    echo "✗ codex CLI is required to register the vault MCP server" >&2
  else
    MCP_DIR="$INSTALL_DIR/mcp"
    mkdir -p "$MCP_DIR"
    cp "$SCRIPT_DIR/mcp/requirements.txt" "$SCRIPT_DIR/mcp/server.py" \
      "$SCRIPT_DIR/mcp/db.py" "$SCRIPT_DIR/mcp/indexer.py" "$SCRIPT_DIR/mcp/searcher.py" "$MCP_DIR/"
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
  install_hooks
fi

echo
echo "=== Codex setup complete ==="
echo 'Start a new Codex session, then use a workflow such as $review or $vault-search.'
echo "For a shared vault outside the default path, export PIMP_MY_VAULT_DIR before starting Codex."
