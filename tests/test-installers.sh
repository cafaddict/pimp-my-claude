#!/bin/bash
# shellcheck disable=SC2088  # settings.json stores literal "~/" commands; compare them as text.
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
# The installers read the vault path from these; a real vault must not leak into the tests.
unset PIMP_MY_VAULT_DIR CLAUDE_VAULT_DIR

bash -n "$REPO_DIR/setup.sh" "$REPO_DIR/setup-codex.sh" "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/bin/*.sh "$REPO_DIR"/lib/*.sh
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
test -f "$(ls -d "$CODEX_HOME/pimp-my-codex/backups/"*/ | head -1)hooks.json"
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
# Team skills and agents only propose vault notes; the write waits for the user's request or approval.
for f in skills/debug-team/SKILL.md skills/review-team/SKILL.md skills/taskloop/SKILL.md skills/sdd/SKILL.md agents/architect.md; do
  rg -F '사용자가 요청·승인한 경우에만' "$REPO_DIR/$f" >/dev/null
done
refute rg 'vault-note 스킬로 vault .*기록하라|\(note 스킬\)|/note로' "$REPO_DIR/skills" "$REPO_DIR/agents"
# Claude Code ignores unknown skill frontmatter keys silently, so only documented fields may appear.
known_keys='^(name|description|when_to_use|argument-hint|arguments|disable-model-invocation|user-invocable|allowed-tools|disallowed-tools|model|effort|context|agent|background|hooks|paths|shell|metadata|license|compatibility)$'
# A forked skill that takes arguments (declares `argument-hint` or `arguments`) must use the full
# $ARGUMENTS placeholder. Claude Code appends `ARGUMENTS: <input>` only when no placeholder receives an
# argument, so once $0 or a named argument is filled the rest of the typed text is dropped, and a forked
# subagent cannot see the conversation. Indexed forms such as $ARGUMENTS[0] do not carry the full text.
is_fork() { frontmatter "$1" | rg -q "^[[:space:]]*context[[:space:]]*:[[:space:]]*[\"']?fork[\"']?[[:space:]]*(#.*)?$"; }
takes_arguments() { frontmatter "$1" | rg -q '^[[:space:]]*(argument-hint|arguments)[[:space:]]*:'; }
has_full_arguments() { body "$1" | rg -q '\$ARGUMENTS([^\[A-Za-z0-9_]|$)'; }
fork_arguments_ok() {
  is_fork "$1" && takes_arguments "$1" || return 0
  has_full_arguments "$1"
}
for f in "$REPO_DIR"/skills/*/SKILL.md; do
  frontmatter "$f" | sed -n 's/^\([A-Za-z_-]*\):.*/\1/p' | while read -r key; do
    printf '%s\n' "$key" | rg -q "$known_keys" || { echo "unknown frontmatter key '$key' in $f" >&2; exit 1; }
  done
  fork_arguments_ok "$f" || { echo "forked skill takes arguments but has no \$ARGUMENTS: $f" >&2; exit 1; }
done
FORK_CASES="$TEST_DIR/fork-cases"
mkdir -p "$FORK_CASES"
fork_case() { printf -- '---\nname: case\ndescription: case\n%s\n---\n%s\n' "$2" "$3" > "$FORK_CASES/$1.md"; }
fork_case double-quoted $'context: "fork"\nargument-hint: "[pr]"' 'Review PR $0.'
fork_case single-quoted $'context: \'fork\'  \nargument-hint: "[pr]"' 'Review PR $0.'
fork_case spaced $'  context :   fork   # isolated\nargument-hint: "[pr]"' 'Review PR $0.'
fork_case named-only $'context: fork\narguments: [pr]' 'Review PR $pr.'
fork_case indexed-only $'context: fork\nargument-hint: "[pr]"' 'Review PR $ARGUMENTS[0].'
fork_case no-arguments $'context: fork' 'Summarize the repository layout.'
fork_case full-arguments $'context: "fork"\nargument-hint: "[pr]"' 'Review PR $0. Request: $ARGUMENTS'
fork_case inline $'argument-hint: "[pr]"' 'Review PR $0.'
for c in double-quoted single-quoted spaced named-only indexed-only; do
  if fork_arguments_ok "$FORK_CASES/$c.md"; then echo "fork case '$c' should be rejected" >&2; exit 1; fi
done
for c in no-arguments full-arguments inline; do
  fork_arguments_ok "$FORK_CASES/$c.md" || { echo "fork case '$c' should pass" >&2; exit 1; }
done

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

# --- Codex render: paths are never rewritten as `$skill` names ------------------------------
# Path segments such as /review/ and /vault-x/ used to be rewritten into `$review`, `$vault-x`.
R_AGENTS="$TEST_DIR/render/review/vault-x/agents"
R_CODEX="$TEST_DIR/render/vault-y/codex"
HOME="$TEST_DIR/render-home" CODEX_HOME="$R_CODEX" AGENTS_HOME="$R_AGENTS" PIMP_MY_VAULT_DIR="$TEST_DIR/render-vault" \
  "$REPO_DIR/setup-codex.sh" >/dev/null
PW="$R_AGENTS/skills/plain-words/SKILL.md"
rg -F "$R_AGENTS/skills/plain-words/scripts/check.py" "$PW" >/dev/null
refute rg -e '[A-Za-z0-9_/]\$(plain-words|review|vault-)' "$R_AGENTS/skills"
rg -F '`$vault-note`' "$R_AGENTS/skills/vault-search/SKILL.md" >/dev/null
rg -F "$R_CODEX/pimp-my-codex/bin/vault-sync.sh --pull" "$R_AGENTS/skills/vault-search/SKILL.md" >/dev/null
# Run the checker exactly as the rendered skill names it.
CHECKER="$(rg -o '^python (\S+/check\.py) --list' -r '$1' "$PW")"
test -f "$CHECKER"
python3 -I "$CHECKER" --list >/dev/null
printf '%s\n' 'We utilize the queue.' > "$TEST_DIR/prose.md"
refute python3 -I "$CHECKER" "$TEST_DIR/prose.md"

# --- Claude settings: clean install, re-run, explicit upgrade, rollback ----------------------
settings_of() { echo "$1/.claude/settings.json"; }
FRESH="$TEST_DIR/fresh-home"
mkdir -p "$FRESH"
HOME="$FRESH" "$REPO_DIR/setup.sh" >/dev/null
cmp "$REPO_DIR/settings-template.json" "$(settings_of "$FRESH")"
test ! -e "$FRESH/.claude/hooks/prompt-hint.sh"
test ! -e "$REPO_DIR/hooks/prompt-hint.sh"  # retired: removed from source, never from an install
cp "$(settings_of "$FRESH")" "$TEST_DIR/fresh-1.json"
HOME="$FRESH" "$REPO_DIR/setup.sh" >/dev/null
cmp "$TEST_DIR/fresh-1.json" "$(settings_of "$FRESH")"
HOME="$FRESH" "$REPO_DIR/setup.sh" --upgrade-hooks | rg -F '변경 없음' >/dev/null
test ! -d "$FRESH/.claude/pimp-my-claude-backups"

# An existing install from an older version, plus things the user added.
UP="$TEST_DIR/upgrade-home"
UPS="$(settings_of "$UP")"
UP_VAULT="$TEST_DIR/upgrade-vault"
mkdir -p "$UP/.claude/hooks" "$UP/.claude/skills/guide" "$UP_VAULT/sessions/pre-compact"
printf '%s\n' 'legacy transcript sentinel' > "$UP_VAULT/sessions/pre-compact/transcript-old.jsonl"
printf '%s\n' 'legacy log sentinel' > "$UP_VAULT/sessions/subagent-activity.log"
(cd "$UP_VAULT" && cksum sessions/pre-compact/transcript-old.jsonl sessions/subagent-activity.log) > "$TEST_DIR/legacy-before"
cat > "$UPS" <<'JSON'
{
  "statusLine": {"type": "command", "command": "cc-status", "padding": 0},
  "env": {"MY_FLAG": "1"},
  "permissions": {"additionalDirectories": ["/keep"]},
  "hooks": {
    "UserPromptSubmit": [
      {"matcher": "", "hooks": [
        {"type": "command", "command": "~/.claude/hooks/prompt-hint.sh", "timeout": 1000},
        {"type": "command", "command": "~/.claude/hooks/plain-words-remind.sh", "timeout": 1000}
      ]}
    ],
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/vault-briefing.sh", "timeout": 2000}]}],
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [
        {"type": "command", "command": "~/.claude/hooks/block-dangerous.sh", "statusMessage": "명령어 안전성 검증...",
         "if": "Bash(rm *) | Bash(git push *) | Bash(git reset *) | Bash(git clean *) | Bash(*DROP TABLE*) | Bash(*DROP DATABASE*)"},
        {"type": "command", "command": "my-bash-audit --strict"}
      ]},
      {"matcher": "Write|Edit", "hooks": [
        {"type": "command", "command": "~/.claude/hooks/protect-sensitive.sh", "statusMessage": "민감 파일 확인...", "async": true}
      ]}
    ],
    "SubagentStop": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/subagent-stop-log.sh", "timeout": 2000}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": ":"}]}]
  }
}
JSON
cp "$UPS" "$TEST_DIR/upgrade-original.json"
# Installed scripts: one old shipped version, one edited copy, one retired file.
OLD_REV=a696699
if git -C "$REPO_DIR" cat-file -e "$OLD_REV:hooks/block-dangerous.sh" 2>/dev/null; then
  git -C "$REPO_DIR" show "$OLD_REV:hooks/block-dangerous.sh" > "$UP/.claude/hooks/block-dangerous.sh"
  git -C "$REPO_DIR" show "$OLD_REV:hooks/prompt-hint.sh" > "$UP/.claude/hooks/prompt-hint.sh"
  HAS_HISTORY=true
else
  cp "$REPO_DIR/hooks/block-dangerous.sh" "$UP/.claude/hooks/block-dangerous.sh"
  printf '%s\n' '#!/bin/bash' 'exit 0' > "$UP/.claude/hooks/prompt-hint.sh"
  HAS_HISTORY=false
fi
cp "$UP/.claude/hooks/block-dangerous.sh" "$TEST_DIR/old-block-dangerous.sh"
{ cat "$REPO_DIR/hooks/protect-sensitive.sh"; echo '# my local tweak'; } > "$UP/.claude/hooks/protect-sensitive.sh"
cp "$UP/.claude/hooks/protect-sensitive.sh" "$TEST_DIR/edited-protect.sh"
printf '%s\n' '---' 'name: guide' '---' 'my own guide' > "$UP/.claude/skills/guide/SKILL.md"
cp "$UP/.claude/hooks/prompt-hint.sh" "$TEST_DIR/prompt-hint-installed.sh"
chmod +x "$UP/.claude/hooks/"*.sh

uprun() { HOME="$UP" PIMP_MY_VAULT_DIR="$UP_VAULT" CLAUDE_VAULT_DIR="$UP_VAULT" "$REPO_DIR/setup.sh" "$@"; }
count_cmd() { jq --arg e "$1" --arg c "$2" '[.hooks[$e][]?.hooks[]? | select(.command == $c)] | length' "$UPS"; }

# Default re-run: existing values win, nothing is bound twice, edited files stay.
uprun > "$TEST_DIR/rerun.out"
rg -F -- '--upgrade-hooks' "$TEST_DIR/rerun.out" >/dev/null
jq -e '.statusLine == {"type": "command", "command": "cc-status", "padding": 0}' "$UPS" >/dev/null
jq -e '.env.MY_FLAG == "1" and (.permissions.additionalDirectories | index("/keep") and index("~/.claude"))' "$UPS" >/dev/null
jq -e '[.hooks[] | [.[].hooks[]?.command] | group_by(.) | map(length) | max // 0] | max == 1' "$UPS" >/dev/null
test "$(count_cmd UserPromptSubmit '~/.claude/hooks/prompt-hint.sh')" = 1
test "$(count_cmd Stop '~/.claude/hooks/notify-done.sh')" = 1
jq -e '.hooks.PreToolUse[0].hooks[0] | has("if")' "$UPS" >/dev/null
cmp "$TEST_DIR/old-block-dangerous.sh" "$UP/.claude/hooks/block-dangerous.sh"
cmp "$TEST_DIR/edited-protect.sh" "$UP/.claude/hooks/protect-sensitive.sh"
rg -x 'my own guide' "$UP/.claude/skills/guide/SKILL.md" >/dev/null
cp "$UPS" "$TEST_DIR/after-rerun.json"
uprun >/dev/null
cmp "$TEST_DIR/after-rerun.json" "$UPS"

# Dry run: shows a diff, writes nothing.
uprun --upgrade-hooks --dry-run > "$TEST_DIR/dry.out"
rg -F -- '--dry-run' "$TEST_DIR/dry.out" >/dev/null
rg -F -- '-  "hooks"' "$TEST_DIR/dry.out" >/dev/null || rg -F '"if"' "$TEST_DIR/dry.out" >/dev/null
cmp "$TEST_DIR/after-rerun.json" "$UPS"
cmp "$TEST_DIR/old-block-dangerous.sh" "$UP/.claude/hooks/block-dangerous.sh"
ls "$UP/.claude/pimp-my-claude-backups" > "$TEST_DIR/backups-before-upgrade"

# Explicit upgrade.
uprun --upgrade-hooks > "$TEST_DIR/upgrade.out"
NEW_BACKUP="$(comm -13 "$TEST_DIR/backups-before-upgrade" <(ls "$UP/.claude/pimp-my-claude-backups"))"
test "$(printf '%s\n' "$NEW_BACKUP" | wc -l | tr -d ' ')" = 1
BK="$UP/.claude/pimp-my-claude-backups/$NEW_BACKUP"
cmp "$TEST_DIR/after-rerun.json" "$BK/settings.json"
test "$(count_cmd PreToolUse '~/.claude/hooks/block-dangerous.sh')" = 1
jq -e '[.hooks.PreToolUse[].hooks[] | select(.command == "~/.claude/hooks/block-dangerous.sh")][0] | has("if") | not' "$UPS" >/dev/null
jq -e '[.hooks.UserPromptSubmit[].hooks[] | select(.command == "~/.claude/hooks/plain-words-remind.sh")] | length == 1 and .[0].timeout == 5' "$UPS" >/dev/null
test "$(count_cmd UserPromptSubmit '~/.claude/hooks/prompt-hint.sh')" = 0
cmp "$TEST_DIR/prompt-hint-installed.sh" "$UP/.claude/hooks/prompt-hint.sh"
jq -e '.statusLine.command == "cc-status"' "$UPS" >/dev/null
test "$(count_cmd Stop ':')" = 1
test "$(count_cmd PreToolUse 'my-bash-audit --strict')" = 1
jq -e '.hooks.PreToolUse[0].hooks | map(.command) | index("my-bash-audit --strict")' "$UPS" >/dev/null
test "$(count_cmd SessionStart '~/.claude/hooks/vault-briefing.sh')" = 1
test "$(count_cmd SubagentStop '~/.claude/hooks/subagent-stop-log.sh')" = 1
jq -e '[.hooks.PreToolUse[].hooks[] | select(.command == "~/.claude/hooks/protect-sensitive.sh")] | length == 1 and .[0].async == true' "$UPS" >/dev/null
rg -F '보류' "$TEST_DIR/upgrade.out" | rg -F 'protect-sensitive' >/dev/null
cmp "$TEST_DIR/edited-protect.sh" "$UP/.claude/hooks/protect-sensitive.sh"
if [ "$HAS_HISTORY" = true ]; then
  cmp "$REPO_DIR/hooks/block-dangerous.sh" "$UP/.claude/hooks/block-dangerous.sh"
  cmp "$TEST_DIR/old-block-dangerous.sh" "$BK/hooks/block-dangerous.sh"
fi
rg -x 'my own guide' "$UP/.claude/skills/guide/SKILL.md" >/dev/null
# A hook installed as a symlink (e.g. into a dotfiles repo) stays a symlink.
test -L "$UP/.claude/hooks/notify-done.sh" || {
  mv "$UP/.claude/hooks/notify-done.sh" "$TEST_DIR/dotfiles-notify.sh"
  printf '%s\n' '# my dotfiles copy' >> "$TEST_DIR/dotfiles-notify.sh"
  ln -s "$TEST_DIR/dotfiles-notify.sh" "$UP/.claude/hooks/notify-done.sh"
}
uprun --upgrade-hooks >/dev/null
uprun >/dev/null
test -L "$UP/.claude/hooks/notify-done.sh"
test "$(tail -1 "$TEST_DIR/dotfiles-notify.sh")" = '# my dotfiles copy'
cp "$UPS" "$TEST_DIR/after-upgrade.json"
cp "$UP/.claude/hooks/block-dangerous.sh" "$TEST_DIR/after-upgrade-block.sh"

# A second upgrade changes nothing and makes no new backup; the first backup is untouched.
uprun --upgrade-hooks | rg -F '변경 없음' >/dev/null
cmp "$TEST_DIR/after-upgrade.json" "$UPS"
test "$(ls "$UP/.claude/pimp-my-claude-backups" | wc -l | tr -d ' ')" = "$(( $(wc -l < "$TEST_DIR/backups-before-upgrade") + 1 ))"
cmp "$TEST_DIR/after-rerun.json" "$BK/settings.json"
# Default re-run after the upgrade keeps it as is.
uprun >/dev/null
cmp "$TEST_DIR/after-upgrade.json" "$UPS"

# Rollback with the printed commands restores the pre-upgrade bytes.
bash "$BK/restore-commands.txt"
cmp "$TEST_DIR/after-rerun.json" "$UPS"
cmp "$TEST_DIR/old-block-dangerous.sh" "$UP/.claude/hooks/block-dangerous.sh"
# Legacy vault data is never moved or changed by any of the runs above.
(cd "$UP_VAULT" && cksum sessions/pre-compact/transcript-old.jsonl sessions/subagent-activity.log) > "$TEST_DIR/legacy-after"
cmp "$TEST_DIR/legacy-before" "$TEST_DIR/legacy-after"
test ! -e "$UP/.claude/pre-compact-backups"

# Malformed settings: stop before changing anything.
BAD="$TEST_DIR/bad-home"
mkdir -p "$BAD/.claude"
printf '%s\n' '{"hooks": ' > "$BAD/.claude/settings.json"
cp "$BAD/.claude/settings.json" "$TEST_DIR/bad.json"
refute env HOME="$BAD" "$REPO_DIR/setup.sh"
cmp "$TEST_DIR/bad.json" "$BAD/.claude/settings.json"
test ! -e "$BAD/.claude/hooks"
refute env HOME="$BAD" "$REPO_DIR/setup.sh" --upgrade-hooks
cmp "$TEST_DIR/bad.json" "$BAD/.claude/settings.json"
printf '%s\n' '{"hooks": []}' > "$BAD/.claude/settings.json"
cp "$BAD/.claude/settings.json" "$TEST_DIR/bad.json"
refute env HOME="$BAD" "$REPO_DIR/setup.sh" --upgrade-hooks
cmp "$TEST_DIR/bad.json" "$BAD/.claude/settings.json"
refute env HOME="$BAD" "$REPO_DIR/setup.sh" --dry-run
refute env HOME="$BAD" "$REPO_DIR/setup.sh" --upgrade-hook

# --- Codex hooks: default keeps, --upgrade-hooks replaces only what we shipped --------------
if [ "$HAS_HISTORY" = true ]; then
  CX="$TEST_DIR/codex-up"
  CXI="$CX/pimp-my-codex"
  mkdir -p "$CXI/hooks"
  git -C "$REPO_DIR" show "a3e60f6:codex/hooks.json" | sed "s|{{CODEX_INSTALL_DIR}}|$CXI|g" > "$CX/hooks.json"
  jq '.hooks.Stop[0].hooks += [{"type": "command", "command": "my-codex-notify"}]' "$CX/hooks.json" > "$CX/h.tmp"
  mv "$CX/h.tmp" "$CX/hooks.json"
  for h in plain-words-remind block-dangerous notify-done prompt-hint; do
    git -C "$REPO_DIR" show "a3e60f6:hooks/$h.sh" \
      | sed -e 's/CLAUDE_VAULT_DIR/PIMP_MY_VAULT_DIR/g' -e 's/CLAUDE_CONFIG_REVIEW_DAYS/PIMP_MY_CONFIG_REVIEW_DAYS/g' \
            -e 's/CLAUDE_CONFIG_DIR/CODEX_CONFIG_DIR/g' -e 's#\.claude#\.codex#g' -e 's/Claude Code/Codex/g' \
      > "$CXI/hooks/$h.sh"
  done
  cp "$CX/hooks.json" "$TEST_DIR/codex-original.json"
  cp "$CXI/hooks/block-dangerous.sh" "$TEST_DIR/codex-old-block.sh"
  cxrun() { HOME="$TEST_DIR/codex-up-home" CODEX_HOME="$CX" AGENTS_HOME="$TEST_DIR/codex-up-agents" \
    PIMP_MY_VAULT_DIR="$TEST_DIR/codex-up-vault" "$REPO_DIR/setup-codex.sh" "$@"; }
  cxrun --with-hooks >/dev/null
  cmp "$TEST_DIR/codex-original.json" "$CX/hooks.json"
  cmp "$TEST_DIR/codex-old-block.sh" "$CXI/hooks/block-dangerous.sh"
  cxrun --upgrade-hooks --dry-run >/dev/null
  cmp "$TEST_DIR/codex-original.json" "$CX/hooks.json"
  cxrun --upgrade-hooks >/dev/null
  jq -e '[.hooks.UserPromptSubmit[].hooks[].command] | all(test("prompt-hint") | not)' "$CX/hooks.json" >/dev/null
  test -f "$CXI/hooks/prompt-hint.sh"
  jq -e '[.hooks.SessionStart[].hooks[].command] | any(test("vault-briefing"))' "$CX/hooks.json" >/dev/null
  jq -e '[.hooks.Stop[].hooks[].command] | index("my-codex-notify")' "$CX/hooks.json" >/dev/null
  jq -e '[.hooks[] | [.[].hooks[]?.command] | group_by(.) | map(length) | max // 0] | max == 1' "$CX/hooks.json" >/dev/null
  refute cmp -s "$TEST_DIR/codex-old-block.sh" "$CXI/hooks/block-dangerous.sh"
  CXB="$(ls -d "$CXI/backups/"*/ | head -1)"
  cmp "$TEST_DIR/codex-original.json" "$CXB/hooks.json"
  cp "$CX/hooks.json" "$TEST_DIR/codex-upgraded.json"
  cxrun --upgrade-hooks | rg -F 'Hooks unchanged' >/dev/null
  cmp "$TEST_DIR/codex-upgraded.json" "$CX/hooks.json"
  bash "$CXB/restore-commands.txt"
  cmp "$TEST_DIR/codex-original.json" "$CX/hooks.json"
  cmp "$TEST_DIR/codex-old-block.sh" "$CXI/hooks/block-dangerous.sh"
fi

# --- Codex skills: clean install, known update, your edits kept, re-run idempotent ----------
CXS="$TEST_DIR/cxs-agents"
cxs() { HOME="$TEST_DIR/cxs-home" CODEX_HOME="$TEST_DIR/cxs-codex" AGENTS_HOME="$CXS" \
  PIMP_MY_VAULT_DIR="$TEST_DIR/cxs-vault" "$@"; }
tree_sum() { (cd "$1" && find . -type f | sort | while IFS= read -r f; do cksum "$f"; done); }
cxs "$REPO_DIR/setup-codex.sh" > "$TEST_DIR/cxs-1.out"
cp -R "$CXS/skills" "$TEST_DIR/cxs-ref"
cxs "$REPO_DIR/setup-codex.sh" > "$TEST_DIR/cxs-2.out"
rg -F ': 0 file(s) installed or updated' "$TEST_DIR/cxs-2.out" >/dev/null
refute rg -F 'Kept' "$TEST_DIR/cxs-2.out"
diff -r "$TEST_DIR/cxs-ref" "$CXS/skills" >/dev/null
# Copies installed by earlier installers (their own rendering) are recognised and updated.
if [ "$HAS_HISTORY" = true ]; then
  for rev in a3e60f6 a696699; do
    mv "$CXS/skills" "$TEST_DIR/cxs-before-$rev"
    mkdir -p "$TEST_DIR/old-$rev"
    git -C "$REPO_DIR" archive "$rev" | tar -x -C "$TEST_DIR/old-$rev"
    cxs bash "$TEST_DIR/old-$rev/setup-codex.sh" >/dev/null
    refute diff -r "$TEST_DIR/cxs-ref" "$CXS/skills"
    cxs "$REPO_DIR/setup-codex.sh" > "$TEST_DIR/cxs-$rev.out"
    refute rg -F 'Kept' "$TEST_DIR/cxs-$rev.out"
    diff -r "$TEST_DIR/cxs-ref" "$CXS/skills" >/dev/null
  done
fi
# Edited SKILL.md / checker and files you added are kept; the edited ones are listed.
printf '%s\n' '- my review rule' >> "$CXS/skills/review/SKILL.md"
printf '%s\n' '# my checker tweak' >> "$CXS/skills/plain-words/scripts/check.py"
printf '%s\n' 'my notes' > "$CXS/skills/review/notes.md"
printf '%s\n' 'echo mine' > "$CXS/skills/plain-words/scripts/extra.sh"
tree_sum "$CXS/skills" > "$TEST_DIR/cxs-edited.sum"
cxs "$REPO_DIR/setup-codex.sh" > "$TEST_DIR/cxs-edit.out"
tree_sum "$CXS/skills" > "$TEST_DIR/cxs-now.sum"; cmp "$TEST_DIR/cxs-now.sum" "$TEST_DIR/cxs-edited.sum"
rg -F 'Kept 2 skill file(s)' "$TEST_DIR/cxs-edit.out" >/dev/null
rg -F "$CXS/skills/review/SKILL.md" "$TEST_DIR/cxs-edit.out" >/dev/null
rg -F "$CXS/skills/plain-words/scripts/check.py" "$TEST_DIR/cxs-edit.out" >/dev/null
cxs "$REPO_DIR/setup-codex.sh" >/dev/null
tree_sum "$CXS/skills" > "$TEST_DIR/cxs-now.sum"; cmp "$TEST_DIR/cxs-now.sum" "$TEST_DIR/cxs-edited.sum"
# The printed review/rollback steps work.
mv "$CXS/skills/review/SKILL.md" "$CXS/skills/review/SKILL.md.mine"
cxs "$REPO_DIR/setup-codex.sh" >/dev/null
cmp "$TEST_DIR/cxs-ref/review/SKILL.md" "$CXS/skills/review/SKILL.md"
mv "$CXS/skills/review/SKILL.md.mine" "$CXS/skills/review/SKILL.md"
tree_sum "$CXS/skills" > "$TEST_DIR/cxs-now.sum"; cmp "$TEST_DIR/cxs-now.sum" "$TEST_DIR/cxs-edited.sum"
# --upgrade-hooks never touches skills.
cxs "$REPO_DIR/setup-codex.sh" --upgrade-hooks >/dev/null 2>&1 || true
tree_sum "$CXS/skills" > "$TEST_DIR/cxs-now.sum"; cmp "$TEST_DIR/cxs-now.sum" "$TEST_DIR/cxs-edited.sum"

# --- /guide frontmatter extraction keeps multi-line descriptions ---------------------------
eval "$(sed -n '/^   fm() {/,/cut -c1-200; }$/p' "$FRESH/.claude/skills/guide/SKILL.md")"
for f in "$REPO_DIR"/agents/*.md "$REPO_DIR"/skills/*/SKILL.md; do
  if frontmatter "$f" | rg -q '^description: *[|>]'; then
    fm "$f" | awk '/^description:/{d=1;next} d && /^[[:space:]]+[^[:space:]]/{ok=1} END{exit !ok}' \
      || { echo "guide: multi-line description lost for $f" >&2; exit 1; }
  fi
done
fm "$REPO_DIR/agents/researcher.md" | rg -F '리서치 전문가' >/dev/null
fm "$REPO_DIR/agents/researcher.md" | rg '^tools:' >/dev/null

# --- Paths the rendered commands cannot run from are refused before any write ---------------
refute env HOME="$TEST_DIR/sp-home" CODEX_HOME="$TEST_DIR/sp ace/codex" AGENTS_HOME="$TEST_DIR/sp-agents" \
  "$REPO_DIR/setup-codex.sh" --with-hooks
test ! -e "$TEST_DIR/sp ace" && test ! -e "$TEST_DIR/sp-agents"
refute env HOME="$TEST_DIR/sp-home" CODEX_HOME="$TEST_DIR/sp-codex" AGENTS_HOME="$TEST_DIR/a&b|c/agents" \
  "$REPO_DIR/setup-codex.sh"
test ! -e "$TEST_DIR/sp-codex" && test ! -e "$TEST_DIR/a&b|c"
mkdir -p "$TEST_DIR/my repo"
cp -R "$REPO_DIR/setup.sh" "$REPO_DIR/lib" "$REPO_DIR/settings-template.json" "$TEST_DIR/my repo/"
mkdir -p "$TEST_DIR/sp-claude-home"
refute env HOME="$TEST_DIR/sp-claude-home" "$TEST_DIR/my repo/setup.sh"
test ! -e "$TEST_DIR/sp-claude-home/.claude"
# Non-ASCII paths are fine: the rendered checker still runs.
KO="$TEST_DIR/한글/agents"
HOME="$TEST_DIR/ko-home" CODEX_HOME="$TEST_DIR/ko-codex" AGENTS_HOME="$KO" "$REPO_DIR/setup-codex.sh" >/dev/null
KO_CHECKER="$(rg -o '^python (\S+/check\.py) --list' -r '$1' "$KO/skills/plain-words/SKILL.md")"
python3 -I "$KO_CHECKER" --list >/dev/null

# --- settings.json / hooks.json symlink or unreadable structure: stop before any write ------
SYM="$TEST_DIR/sym-home"
mkdir -p "$SYM/.claude"
printf '%s\n' '{"env": {"A": "1"}}' > "$TEST_DIR/dotfiles-settings.json"
cp "$TEST_DIR/dotfiles-settings.json" "$TEST_DIR/dotfiles-settings.orig"
ln -s "$TEST_DIR/dotfiles-settings.json" "$SYM/.claude/settings.json"
refute env HOME="$SYM" "$REPO_DIR/setup.sh"
refute env HOME="$SYM" "$REPO_DIR/setup.sh" --upgrade-hooks
test -L "$SYM/.claude/settings.json"
cmp "$TEST_DIR/dotfiles-settings.orig" "$TEST_DIR/dotfiles-settings.json"
test "$(ls -A "$SYM/.claude")" = settings.json
mkdir -p "$TEST_DIR/sym-codex"
ln -s "$TEST_DIR/dotfiles-settings.json" "$TEST_DIR/sym-codex/hooks.json"
refute env HOME="$SYM" CODEX_HOME="$TEST_DIR/sym-codex" AGENTS_HOME="$TEST_DIR/sym-agents" "$REPO_DIR/setup-codex.sh" --with-hooks
test -L "$TEST_DIR/sym-codex/hooks.json" && test ! -e "$TEST_DIR/sym-agents"
test "$(ls -A "$TEST_DIR/sym-codex")" = hooks.json
STRUCT="$TEST_DIR/struct-home"
mkdir -p "$STRUCT/.claude" "$TEST_DIR/struct-codex"
printf '%s\n' '{"hooks": []}' > "$STRUCT/.claude/settings.json"
refute env HOME="$STRUCT" "$REPO_DIR/setup.sh"
test "$(ls -A "$STRUCT/.claude")" = settings.json
printf '%s\n' '{"hooks": []}' > "$TEST_DIR/struct-codex/hooks.json"
refute env HOME="$STRUCT" CODEX_HOME="$TEST_DIR/struct-codex" AGENTS_HOME="$TEST_DIR/struct-agents" "$REPO_DIR/setup-codex.sh" --with-hooks
test ! -e "$TEST_DIR/struct-agents" && test "$(ls -A "$TEST_DIR/struct-codex")" = hooks.json

# --- --upgrade-hooks keeps a handler's other matcher groups (only same-matcher copies go) ---
if [ "$HAS_HISTORY" = true ]; then
  MG="$TEST_DIR/matcher-home"
  mkdir -p "$MG/.claude"
  git -C "$REPO_DIR" show a696699:settings-template.json | jq '
    .hooks.PreToolUse as $p
    | .hooks.PreToolUse = $p + [($p[0]), ($p[1] | .matcher = "NotebookEdit"), ($p[0] | .matcher = "Bash|Monitor")]' \
    > "$MG/.claude/settings.json"
  HOME="$MG" "$REPO_DIR/setup.sh" --upgrade-hooks > "$TEST_DIR/matcher.out"
  jq -e '[.hooks.PreToolUse[].matcher] == ["Bash", "Write|Edit", "NotebookEdit", "Bash|Monitor"]' "$MG/.claude/settings.json" >/dev/null
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "NotebookEdit") | .hooks[].command] == ["~/.claude/hooks/protect-sensitive.sh"]' "$MG/.claude/settings.json" >/dev/null
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash|Monitor") | .hooks[]] | length == 1 and (.[0] | has("if") | not)' "$MG/.claude/settings.json" >/dev/null
  rg -F '중복 제거' -A1 "$TEST_DIR/matcher.out" | rg -F 'block-dangerous' >/dev/null

  CM="$TEST_DIR/codex-matcher"
  mkdir -p "$CM/pimp-my-codex/hooks"
  git -C "$REPO_DIR" show "a3e60f6:codex/hooks.json" | sed "s|{{CODEX_INSTALL_DIR}}|$CM/pimp-my-codex|g" \
    | jq '.hooks.PreToolUse += [(.hooks.PreToolUse[0] | .matcher = "^apply_patch$")]' > "$CM/hooks.json"
  HOME="$TEST_DIR/cm-home" CODEX_HOME="$CM" AGENTS_HOME="$TEST_DIR/cm-agents" "$REPO_DIR/setup-codex.sh" --upgrade-hooks >/dev/null
  jq -e '[.hooks.PreToolUse[].matcher] == ["^Bash$", "^apply_patch$"]' "$CM/hooks.json" >/dev/null
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "^apply_patch$") | .hooks[].command | test("block-dangerous")] == [true]' "$CM/hooks.json" >/dev/null
fi

# Renamed vault skills: a shipped copy moves to a backup folder with an undo command, an edited one stays.
if [ "$HAS_HISTORY" = true ]; then
  RS="$TEST_DIR/retired-home"
  mkdir -p "$RS/.claude/skills/note" "$RS/.claude/skills/recall"
  git -C "$REPO_DIR" show '46e1d37^:skills/note/SKILL.md' > "$RS/.claude/skills/note/SKILL.md"
  { git -C "$REPO_DIR" show '46e1d37^:skills/recall/SKILL.md'; echo 'my edit'; } > "$RS/.claude/skills/recall/SKILL.md"
  HOME="$RS" "$REPO_DIR/setup.sh" > "$TEST_DIR/retired.out"
  test ! -e "$RS/.claude/skills/note"
  test -d "$RS/.claude/skills/recall"
  rg -F "$RS/.claude/skills/recall" "$TEST_DIR/retired.out" >/dev/null
  RB="$(ls -d "$RS/.claude/pimp-my-claude-backups/"*/)"
  git -C "$REPO_DIR" show '46e1d37^:skills/note/SKILL.md' | cmp - "$RB/skills/note/SKILL.md"
  HOME="$RS" "$REPO_DIR/setup.sh" >/dev/null
  test "$(ls "$RS/.claude/pimp-my-claude-backups" | wc -l | tr -d ' ')" = 1
  bash "$RB/restore-commands.txt"
  git -C "$REPO_DIR" show '46e1d37^:skills/note/SKILL.md' | cmp - "$RS/.claude/skills/note/SKILL.md"
fi

# Global instructions kept in the vault: linked when identical, held when different,
# replaced by a link after a backup with --force-*, and left alone when the vault has none.
VV="$TEST_DIR/link-vault"
mkdir -p "$VV/config"
printf '%s\n' '# my rules' > "$VV/config/claude-global.md"
printf '%s\n' '# my codex rules' > "$VV/config/codex-global.md"

VH="$TEST_DIR/link-same-home"
mkdir -p "$VH/.claude"
cp "$VV/config/claude-global.md" "$VH/.claude/CLAUDE.md"
HOME="$VH" PIMP_MY_VAULT_DIR="$VV" "$REPO_DIR/setup.sh" >/dev/null
test "$(readlink "$VH/.claude/CLAUDE.md")" = "$VV/config/claude-global.md"
test "$(readlink "$VH/.claude/AGENTS.md")" = CLAUDE.md
git -C "$VV" init -q
HOME="$VH" PIMP_MY_VAULT_DIR="$VV" "$REPO_DIR/setup.sh" > "$TEST_DIR/link-same.out"
test "$(readlink "$VH/.claude/CLAUDE.md")" = "$VV/config/claude-global.md"
rg -F 'vault-sync.sh --commit "config: claude-global" -- config/claude-global.md' "$TEST_DIR/link-same.out" >/dev/null
test ! -d "$VH/.claude/pimp-my-claude-backups"

VD="$TEST_DIR/link-diff-home"
mkdir -p "$VD/.claude"
printf '%s\n' '# local rules' > "$VD/.claude/CLAUDE.md"
HOME="$VD" PIMP_MY_VAULT_DIR="$VV" "$REPO_DIR/setup.sh" > "$TEST_DIR/link-diff.out"
test ! -L "$VD/.claude/CLAUDE.md"
rg -F "diff -u $VD/.claude/CLAUDE.md" "$TEST_DIR/link-diff.out" >/dev/null
HOME="$VD" PIMP_MY_VAULT_DIR="$VV" "$REPO_DIR/setup.sh" --force-claude-md >/dev/null
test "$(readlink "$VD/.claude/CLAUDE.md")" = "$VV/config/claude-global.md"
VB="$(ls -d "$VD/.claude/pimp-my-claude-backups/"*/)"
rg -x '# local rules' "$VB/CLAUDE.md" >/dev/null
bash "$VB/restore-commands.txt"
test ! -L "$VD/.claude/CLAUDE.md"
rg -x '# local rules' "$VD/.claude/CLAUDE.md" >/dev/null

CS="$TEST_DIR/link-same-codex"
mkdir -p "$CS"
cp "$VV/config/codex-global.md" "$CS/AGENTS.md"
HOME="$TEST_DIR/lsc-home" CODEX_HOME="$CS" AGENTS_HOME="$TEST_DIR/lsc-agents" PIMP_MY_VAULT_DIR="$VV" \
  "$REPO_DIR/setup-codex.sh" >/dev/null
test "$(readlink "$CS/AGENTS.md")" = "$VV/config/codex-global.md"

CD="$TEST_DIR/link-diff-codex"
mkdir -p "$CD"
printf '%s\n' '# local codex rules' > "$CD/AGENTS.md"
HOME="$TEST_DIR/ldc-home" CODEX_HOME="$CD" AGENTS_HOME="$TEST_DIR/ldc-agents" PIMP_MY_VAULT_DIR="$VV" \
  "$REPO_DIR/setup-codex.sh" > "$TEST_DIR/link-diff-codex.out"
test ! -L "$CD/AGENTS.md"
rg -F "diff -u $CD/AGENTS.md" "$TEST_DIR/link-diff-codex.out" >/dev/null
HOME="$TEST_DIR/ldc-home" CODEX_HOME="$CD" AGENTS_HOME="$TEST_DIR/ldc-agents" PIMP_MY_VAULT_DIR="$VV" \
  "$REPO_DIR/setup-codex.sh" --force-agents >/dev/null
test "$(readlink "$CD/AGENTS.md")" = "$VV/config/codex-global.md"
rg -x '# local codex rules' "$CD"/pimp-my-codex/backups/*/AGENTS.md >/dev/null

PYTHONPYCACHEPREFIX="$TEST_DIR/pycache" python3 -m py_compile "$REPO_DIR"/mcp/*.py
bash "$REPO_DIR/tests/test-codex-port.sh"
git -C "$REPO_DIR" diff --check

echo "installer contracts passed"
