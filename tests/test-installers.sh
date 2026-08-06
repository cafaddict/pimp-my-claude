#!/bin/bash
# Lightweight contracts for installers. Does not touch the real home directory.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

bash -n "$REPO_DIR/setup.sh" "$REPO_DIR/setup-codex.sh" "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/bin/*.sh
jq empty "$REPO_DIR/settings-template.json" "$REPO_DIR/codex/hooks.json"

CLAUDE_HOME="$TEST_DIR/claude-home"
mkdir -p "$CLAUDE_HOME/.claude"
printf '%s\n' '{"permissions":{"additionalDirectories":["/keep"]},"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"keep-session"}]}]}}' > "$CLAUDE_HOME/.claude/settings.json"
HOME="$CLAUDE_HOME" "$REPO_DIR/setup.sh" >/dev/null
jq -e '.permissions.additionalDirectories | index("/keep") and index("~/.claude")' "$CLAUDE_HOME/.claude/settings.json" >/dev/null
jq -e '.hooks.SessionStart[0].hooks[0].command == "keep-session"' "$CLAUDE_HOME/.claude/settings.json" >/dev/null
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(test("plain-words-remind"))' "$CLAUDE_HOME/.claude/settings.json" >/dev/null

CODEX_HOME="$TEST_DIR/codex"
AGENTS_HOME="$TEST_DIR/agents"
mkdir -p "$CODEX_HOME"
printf '%s\n' '{"hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"keep-session"}]}]}}' > "$CODEX_HOME/hooks.json"
HOME="$TEST_DIR/codex-home" CODEX_HOME="$CODEX_HOME" AGENTS_HOME="$AGENTS_HOME" PIMP_MY_VAULT_DIR="$TEST_DIR/vault" \
  "$REPO_DIR/setup-codex.sh" --with-hooks >/dev/null
jq -e '.hooks.SessionStart[0].hooks[0].command == "keep-session"' "$CODEX_HOME/hooks.json" >/dev/null
jq -e '.hooks.PreToolUse | length == 1' "$CODEX_HOME/hooks.json" >/dev/null
jq -e '.hooks.Stop | length == 1' "$CODEX_HOME/hooks.json" >/dev/null
test -f "$CODEX_HOME/hooks.json.bak"
test -f "$AGENTS_HOME/skills/vault-search/SKILL.md"
test -x "$CODEX_HOME/pimp-my-codex/bin/vault-sync.sh"
rg -F "$CODEX_HOME/pimp-my-codex/bin/vault-sync.sh" "$AGENTS_HOME/skills/vault-search/SKILL.md" >/dev/null
rg -F 'vault skills are the exception' "$CODEX_HOME/AGENTS.md" >/dev/null
! rg -F '["$' "$REPO_DIR/skills/vault-save/SKILL.md" "$REPO_DIR/skills/vault-daily/SKILL.md" "$REPO_DIR/skills/vault-distill/SKILL.md"

GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.email "test@example.com"
git config --file "$GIT_CONFIG_GLOBAL" user.name "Installer Test"
CODEX_VAULT="$TEST_DIR/codex-vault"
HOME="$TEST_DIR/codex-vault-home" CODEX_HOME="$TEST_DIR/codex-vault-config" AGENTS_HOME="$TEST_DIR/codex-vault-agents" \
  PIMP_MY_VAULT_DIR="$CODEX_VAULT" GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" "$REPO_DIR/setup-codex.sh" --with-vault >/dev/null
test "$(git -C "$CODEX_VAULT" rev-list --count HEAD)" = "1"
git -C "$CODEX_VAULT" ls-tree -r --name-only HEAD | rg -F 'templates/session.md' >/dev/null

PROJECT_DIR="$TEST_DIR/project"
VAULT_DIR="$TEST_DIR/project-vault"
mkdir -p "$PROJECT_DIR" "$VAULT_DIR/projects"
(
  cd "$PROJECT_DIR"
  PIMP_MY_VAULT_DIR="$VAULT_DIR" "$REPO_DIR/init-project.sh" python >/dev/null
)
test -f "$VAULT_DIR/projects/project.md"
test ! -d "$VAULT_DIR/projects/project"

SYNC_REMOTE="$TEST_DIR/vault-remote.git"
SYNC_VAULT="$TEST_DIR/sync-vault"
git init --bare "$SYNC_REMOTE" --quiet
git init "$SYNC_VAULT" --quiet
git -C "$SYNC_VAULT" config user.email "test@example.com"
git -C "$SYNC_VAULT" config user.name "Installer Test"
git -C "$SYNC_VAULT" remote add origin "$SYNC_REMOTE"
mkdir -p "$SYNC_VAULT/lessons"
printf '%s\n' '# Synced lesson' > "$SYNC_VAULT/lessons/test.md"
PIMP_MY_VAULT_DIR="$SYNC_VAULT" "$REPO_DIR/bin/vault-sync.sh" --commit "test: vault sync" -- "lessons/test.md" >/dev/null
test "$(git -C "$SYNC_REMOTE" rev-list --count HEAD)" = "1"
printf '%s\n' 'local draft' > "$SYNC_VAULT/local-draft.md"
PIMP_MY_VAULT_DIR="$SYNC_VAULT" "$REPO_DIR/bin/vault-sync.sh" --pull >/dev/null
test "$(cat "$SYNC_VAULT/local-draft.md")" = "local draft"

python3 -m py_compile "$REPO_DIR"/mcp/*.py
git -C "$REPO_DIR" diff --check

echo "installer contracts passed"
