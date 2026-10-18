#!/bin/bash
# Lightweight contracts for installers. Does not touch the real home directory.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pimp-test.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

# `! cmd` never trips `set -e`, so negative checks go through this helper.
refute() {
  if "$@" >/dev/null 2>&1; then
    echo "unexpected success: $*" >&2
    exit 1
  fi
}

# Never read the real git config, hooks, or signing setup.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.email "test@example.com"
git config --file "$GIT_CONFIG_GLOBAL" user.name "Installer Test"
git config --file "$GIT_CONFIG_GLOBAL" core.hooksPath /dev/null
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

bash -n "$REPO_DIR/setup.sh" "$REPO_DIR/setup-codex.sh" "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/bin/*.sh
jq empty "$REPO_DIR/settings-template.json" "$REPO_DIR/codex/hooks.json"

CLAUDE_HOME="$TEST_DIR/claude-home"
mkdir -p "$CLAUDE_HOME/.claude"
printf '%s\n' '{"permissions":{"additionalDirectories":["/keep"]},"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"keep-session"}]}]}}' > "$CLAUDE_HOME/.claude/settings.json"
HOME="$CLAUDE_HOME" "$REPO_DIR/setup.sh" >/dev/null
jq -e '.permissions.additionalDirectories | index("/keep") and index("~/.claude")' "$CLAUDE_HOME/.claude/settings.json" >/dev/null
jq -e '.hooks.SessionStart[0].hooks[0].command == "keep-session"' "$CLAUDE_HOME/.claude/settings.json" >/dev/null
jq -e '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(test("plain-words-remind"))' "$CLAUDE_HOME/.claude/settings.json" >/dev/null
cmp "$REPO_DIR/bin/statusline.sh" "$CLAUDE_HOME/.claude/bin/statusline.sh"
cmp "$REPO_DIR/bin/vault-sync.sh" "$CLAUDE_HOME/.claude/bin/vault-sync.sh"

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
cmp "$REPO_DIR/bin/vault-sync.sh" "$CODEX_HOME/pimp-my-codex/bin/vault-sync.sh"
rg -F "$CODEX_HOME/pimp-my-codex/bin/vault-sync.sh" "$AGENTS_HOME/skills/vault-search/SKILL.md" >/dev/null
rg -F 'vault skills are the exception' "$CODEX_HOME/AGENTS.md" >/dev/null
refute rg -F 'multi-ai' "$CODEX_HOME/AGENTS.md"
refute rg -F '["$' "$REPO_DIR/skills/vault-save/SKILL.md" "$REPO_DIR/skills/vault-daily/SKILL.md" "$REPO_DIR/skills/vault-distill/SKILL.md"
refute rg -F '자동으로 사용하라' "$REPO_DIR/skills/vault-save/SKILL.md"

# Skills that write and push vault notes start only on an explicit user request.
# Claude reads the frontmatter flag; Codex copies must keep the condition in the body.
frontmatter() { awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { exit } f' "$1"; }
body() { awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { f = 0; next } !f' "$1"; }
for skill in vault-daily vault-add-project; do
  frontmatter "$CLAUDE_HOME/.claude/skills/$skill/SKILL.md" | rg -x 'disable-model-invocation: true' >/dev/null
  frontmatter "$REPO_DIR/skills/$skill/SKILL.md" | rg '^description:' | refute rg -F '마무리'
  body "$REPO_DIR/skills/$skill/SKILL.md" | rg -F '**실행 조건:** 사용자가' >/dev/null
done
frontmatter "$AGENTS_HOME/skills/vault-daily/SKILL.md" | rg '^description:' | refute rg -F '마무리'
body "$AGENTS_HOME/skills/vault-daily/SKILL.md" | rg -F '"마무리", "오늘 여기까지" 같은 말만으로는 시작하지 말고' >/dev/null
body "$AGENTS_HOME/skills/vault-daily/SKILL.md" | rg -F '사용자가 요청·승인한 daily 작업이면' >/dev/null

CODEX_VAULT="$TEST_DIR/codex-vault"
HOME="$TEST_DIR/codex-vault-home" CODEX_HOME="$TEST_DIR/codex-vault-config" AGENTS_HOME="$TEST_DIR/codex-vault-agents" \
  PIMP_MY_VAULT_DIR="$CODEX_VAULT" "$REPO_DIR/setup-codex.sh" --with-vault >/dev/null
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

# vault-sync: only the listed files are committed and pushed; local work keeps its staged state.
sync() { PIMP_MY_VAULT_DIR="$SYNC_VAULT" "$REPO_DIR/bin/vault-sync.sh" "$@" >/dev/null 2>&1; }
remote_head() { git -C "$SYNC_REMOTE" rev-parse main; }
printf '%s\n' 'a' > "$SYNC_VAULT/lessons/a.md"
printf '%s\n' 'b' > "$SYNC_VAULT/lessons/b.md"
sync --commit "test: base" -- lessons/a.md lessons/b.md
refute git -C "$SYNC_REMOTE" cat-file -e main:local-draft.md
OTHER="$TEST_DIR/other-clone"
git clone --quiet "$SYNC_REMOTE" "$OTHER"
printf '%s\n' 'remote' > "$OTHER/remote.md"
git -C "$OTHER" add remote.md
git -C "$OTHER" commit --quiet -m "remote change"
git -C "$OTHER" push --quiet origin main
printf '%s\n' 'a staged' > "$SYNC_VAULT/lessons/a.md"
git -C "$SYNC_VAULT" add lessons/a.md
printf '%s\n' 'b unstaged' > "$SYNC_VAULT/lessons/b.md"
printf '%s\n' 'new staged' > "$SYNC_VAULT/staged-new.md"
git -C "$SYNC_VAULT" add staged-new.md
printf '%s\n' 'note' > "$SYNC_VAULT/lessons/note.md"
sync --commit "test: note only" -- lessons/note.md
test "$(git -C "$SYNC_REMOTE" log -1 --format= --name-only main)" = "lessons/note.md"
test "$(remote_head)" = "$(git -C "$SYNC_VAULT" rev-parse HEAD)"
test -f "$SYNC_VAULT/remote.md"
test "$(git -C "$SYNC_VAULT" diff --cached --name-only | tr '\n' ' ')" = "lessons/a.md staged-new.md "
test "$(git -C "$SYNC_VAULT" show :lessons/a.md)" = "a staged"
test "$(git -C "$SYNC_VAULT" diff --name-only)" = "lessons/b.md"
git -C "$SYNC_VAULT" ls-files --others --exclude-standard | rg -x 'local-draft.md' >/dev/null
test -z "$(git -C "$SYNC_VAULT" stash list)"

# Paths outside the vault, directories, globs, and missing files are refused before any change.
printf '%s\n' 'outside' > "$TEST_DIR/outside.md"
printf '%s\n' 'note v2' > "$SYNC_VAULT/lessons/note.md"
BEFORE_HEAD="$(git -C "$SYNC_VAULT" rev-parse HEAD)"
BEFORE_REMOTE="$(remote_head)"
for bad in ../outside.md "$SYNC_VAULT/lessons/note.md" . lessons lessons/ .git/config .GIT/config 'lessons/*.md' ':(top)lessons/note.md' missing.md; do
  refute sync --commit "test: bad" -- "$bad"
done
test "$(git -C "$SYNC_VAULT" rev-parse HEAD)" = "$BEFORE_HEAD"
test "$(remote_head)" = "$BEFORE_REMOTE"
test "$(git -C "$SYNC_VAULT" diff --cached --name-only | tr '\n' ' ')" = "lessons/a.md staged-new.md "
test -z "$(git -C "$SYNC_VAULT" stash list)"

# A held lock stops the run without touching anything.
mkdir "$SYNC_VAULT/.git/pimp-vault-sync.lock"
refute sync --commit "test: locked" -- lessons/note.md
rmdir "$SYNC_VAULT/.git/pimp-vault-sync.lock"
test "$(git -C "$SYNC_VAULT" rev-parse HEAD)" = "$BEFORE_HEAD"
test "$(cat "$SYNC_VAULT/lessons/note.md")" = "note v2"

# Earlier unpushed commits are not published by a note sync.
git -C "$SYNC_VAULT" commit --quiet -m "local only" -- lessons/b.md
refute sync --commit "test: note v2" -- lessons/note.md
test "$(remote_head)" = "$BEFORE_REMOTE"
git -C "$SYNC_VAULT" diff --name-only | rg -x 'lessons/note.md' >/dev/null
test -z "$(git -C "$SYNC_VAULT" stash list)"
git -C "$SYNC_VAULT" push --quiet

# A conflict while restoring local changes stops and keeps them in the stash.
git -C "$OTHER" pull --quiet --rebase
printf '%s\n' 'remote edit' > "$OTHER/lessons/note.md"
git -C "$OTHER" commit --quiet -am "remote note edit"
git -C "$OTHER" push --quiet origin main
refute sync --pull
test "$(git -C "$SYNC_VAULT" stash list | wc -l | tr -d ' ')" = "1"
test "$(git -C "$SYNC_VAULT" show 'stash@{0}:lessons/note.md')" = "note v2"
test "$(git -C "$SYNC_VAULT" show 'stash@{0}^2:lessons/a.md')" = "a staged"
refute test -d "$SYNC_VAULT/.git/pimp-vault-sync.lock"

# A failed restore may bring back nothing or only part of the local work, so the
# message must keep the stash, name what is missing, and never suggest dropping it.
# restore_vault <name> sets up $RV (vault) and $RO (another clone) on a fresh bare remote.
restore_vault() {
  RR="$TEST_DIR/restore-$1.git"; RV="$TEST_DIR/restore-$1"; RO="$TEST_DIR/restore-$1-other"
  git init --quiet --bare "$RR"
  git init --quiet "$RV"
  git -C "$RV" remote add origin "$RR"
  printf '%s\n' 'base' > "$RV/f.md"
  PIMP_MY_VAULT_DIR="$RV" "$REPO_DIR/bin/vault-sync.sh" --commit "test: base" -- f.md >/dev/null 2>&1
  git clone --quiet "$RR" "$RO"
}
restore_fails() {  # expected stderr lines follow
  local err="$TEST_DIR/restore.err" sha want
  if PIMP_MY_VAULT_DIR="$RV" "$REPO_DIR/bin/vault-sync.sh" --pull >/dev/null 2>"$err"; then
    echo "restore conflict: sync unexpectedly succeeded" >&2; exit 1
  fi
  test "$(git -C "$RV" stash list | wc -l | tr -d ' ')" = "1"
  sha="$(git -C "$RV" rev-parse 'stash@{0}')"
  for want in "$sha" 'Do NOT drop' "$@"; do
    rg -F -- "$want" "$err" >/dev/null || { echo "restore conflict message missing: $want" >&2; cat "$err" >&2; exit 1; }
  done
  refute rg -i 'stash (drop|clear)' "$err"
  refute test -d "$RV/.git/pimp-vault-sync.lock"
}

# Case A: a staged edit overlaps the pulled edit; `apply --index` restores nothing.
restore_vault staged
printf '%s\n' 'remote' > "$RO/f.md"
git -C "$RO" commit --quiet -am "remote f"
git -C "$RO" push --quiet origin main
printf '%s\n' 'staged' > "$RV/f.md"
git -C "$RV" add f.md
printf '%s\n' 'staged then edited' > "$RV/f.md"
printf '%s\n' 'draft' > "$RV/draft.md"
restore_fails 'working tree: f.md' 'staged: f.md' 'untracked: draft.md'
test "$(git -C "$RV" show 'stash@{0}:f.md')" = "staged then edited"
test "$(git -C "$RV" show 'stash@{0}^2:f.md')" = "staged"
test "$(git -C "$RV" show 'stash@{0}^3:draft.md')" = "draft"
test "$(cat "$RV/f.md")" = "remote"
test ! -e "$RV/draft.md"

# Case B: a new local note has the same path as a pulled file; only that note is lost
# from the working tree while the other changes come back.
restore_vault untracked
printf '%s\n' 'remote daily' > "$RO/daily.md"
git -C "$RO" add daily.md
git -C "$RO" commit --quiet -m "remote daily"
git -C "$RO" push --quiet origin main
printf '%s\n' 'local daily' > "$RV/daily.md"
printf '%s\n' 'local edit' > "$RV/f.md"
restore_fails 'untracked: daily.md'
refute rg -F 'working tree: f.md' "$TEST_DIR/restore.err"
test "$(git -C "$RV" show 'stash@{0}^3:daily.md')" = "local daily"
test "$(git -C "$RV" show 'stash@{0}:f.md')" = "local edit"
test "$(cat "$RV/daily.md")" = "remote daily"

# statusLine: synthetic JSON only; language detection must not run toolchain binaries.
SL_HOME="$TEST_DIR/sl-home"
SL_BIN="$TEST_DIR/sl-bin"
SL_PROJECT="$TEST_DIR/sl-project"
mkdir -p "$SL_HOME/Downloads/notes" "$SL_BIN" "$SL_PROJECT"
touch "$SL_PROJECT/Cargo.toml"
for tool in rustc rustup cargo node go python3; do
  printf '#!/bin/sh\ntouch "%s/ran-%s"\n' "$TEST_DIR" "$tool" > "$SL_BIN/$tool"
  chmod +x "$SL_BIN/$tool"
done
statusline() {
  jq -n --arg dir "$1" '{model:{display_name:"Opus"},workspace:{current_dir:$dir},
    context_window:{used_percentage:25.6},rate_limits:{five_hour:{used_percentage:23.5}}}' \
    | HOME="$SL_HOME" PATH="$SL_BIN:$PATH" VIRTUAL_ENV="$TEST_DIR/venv" "$REPO_DIR/bin/statusline.sh"
}
SL_OUT="$(statusline "$SL_PROJECT")"
for want in 'Opus' '◔ 26%' '5h 24%' ' rust ' 'venv 🐍' "$(printf '\356\202\260')"; do
  case "$SL_OUT" in *"$want"*) ;; *) echo "statusline missing: $want" >&2; exit 1 ;; esac
done
test -z "$(find "$TEST_DIR" -maxdepth 1 -name 'ran-*')"
SL_OUT="$(statusline "$SL_HOME/Downloads/notes")"
case "$SL_OUT" in *"~/$(printf '\357\200\231')/notes"*) ;; *) echo "statusline: Downloads glyph missing" >&2; exit 1 ;; esac

PYTHONPYCACHEPREFIX="$TEST_DIR/pycache" python3 -m py_compile "$REPO_DIR"/mcp/*.py
git -C "$REPO_DIR" diff --check

echo "installer contracts passed"
