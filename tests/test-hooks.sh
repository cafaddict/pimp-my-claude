#!/bin/bash
# Hook contracts: synthetic JSON on stdin -> exit code, stdout/stderr, file effects.
# Everything runs under a temporary HOME; the real home, vault, and settings are never used.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pimp-hooks.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
export CLAUDE_VAULT_DIR="$TEST_DIR/vault"
unset CLAUDE_CONFIG_DIR PIMP_MY_VAULT_DIR PIMP_MY_LOG_DIR PIMP_MY_PRE_COMPACT_DIR CLAUDE_CONFIG_REVIEW_DAYS
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.email "test@example.com"
git config --file "$GIT_CONFIG_GLOBAL" user.name "Hook Test"
git config --file "$GIT_CONFIG_GLOBAL" core.hooksPath /dev/null
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
mkdir -p "$HOME" "$CLAUDE_VAULT_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }
HOOKS="$REPO_DIR/hooks"
OUT="$TEST_DIR/out"
ERR="$TEST_DIR/err"
# run_hook <hook> <stdin-text> [env...] -> sets RC
run_hook() {
  local hook="$1" input="$2"
  shift 2
  RC=0
  printf '%s' "$input" | env "$@" bash "$HOOKS/$hook.sh" >"$OUT" 2>"$ERR" || RC=$?
}
bash_input() { jq -nc --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}'; }

# --- block-dangerous: exit 2 + stderr to block, exit 0 + no output to allow ---------------
while IFS= read -r cmd; do
  run_hook block-dangerous "$(bash_input "$cmd")"
  [ "$RC" = 2 ] || fail "block-dangerous should block (exit 2), got $RC: $cmd"
  [ -s "$ERR" ] || fail "block-dangerous blocked without a reason on stderr: $cmd"
  [ ! -s "$OUT" ] || fail "block-dangerous wrote to stdout: $cmd"
done <<'EOF'
rm -rf /
rm -rf ~
rm -rf ~/
rm -rf "$HOME"
rm -rf ${HOME}/
rm -rf /*
rm -fr .
rm -r -f /
sudo rm -rf /
bash -c "rm -rf /"
/bin/rm -rf /
\rm -rf /
sudo -u root rm -rf /
nice rm -rf /
nice -n 5 rm -rf /
timeout 5 rm -rf /
timeout -s KILL 5 rm -rf /
/usr/bin/env rm -rf /
/usr/bin/git push -f origin main
/usr/bin/git reset --hard
git push -f
git push --force
git push origin main --force
git push origin main -f
cd x && git push -f
git -C repo push --force-with-lease
git reset --hard
git reset --hard HEAD~1
git clean -fd
git clean -xfd
git clean -d -f
DROP TABLE t
psql -c "drop database prod"
EOF
while IFS= read -r cmd; do
  run_hook block-dangerous "$(bash_input "$cmd")"
  [ "$RC" = 0 ] || fail "block-dangerous should allow (exit 0), got $RC: $cmd"
  [ ! -s "$OUT" ] && [ ! -s "$ERR" ] || fail "block-dangerous printed output for an allowed command: $cmd"
done <<'EOF'
rm -rf ./build
rm -rf ~/.claude/skills/foo
rm -rf "$HOME/tmp/cache"
rm -f /tmp/x
git push origin main
git push --follow-tags
git reset --soft HEAD~1
git clean -n
git commit -m "push -f later"
echo "rm -rf /"
/bin/rm -rf ./build
sudo -u rm ls
timeout 5 ls
ls
EOF
# No command field: nothing to check.
run_hook block-dangerous '{"tool_input":{}}'
[ "$RC" = 0 ] || fail "block-dangerous without a command should exit 0, got $RC"
# Input that is not JSON: never a silent pass. Dangerous text still blocks; otherwise exit 1.
run_hook block-dangerous 'not json'
[ "$RC" = 1 ] && [ -s "$ERR" ] || fail "block-dangerous on malformed input should exit 1 with a message, got $RC"
run_hook block-dangerous 'not json; rm -rf /'
[ "$RC" = 2 ] || fail "block-dangerous on malformed input with rm -rf / should block, got $RC"
# jq failing (missing or broken) must not turn into a silent allow.
mkdir -p "$TEST_DIR/badjq"
printf '#!/bin/sh\nexit 127\n' > "$TEST_DIR/badjq/jq"
chmod +x "$TEST_DIR/badjq/jq"
run_hook block-dangerous "$(bash_input 'rm -rf /')" PATH="$TEST_DIR/badjq:$PATH"
[ "$RC" = 2 ] || fail "block-dangerous without jq should still block rm -rf /, got $RC"
run_hook block-dangerous "$(bash_input 'rm -rf "$HOME"')" PATH="$TEST_DIR/badjq:$PATH"
[ "$RC" = 2 ] || fail "block-dangerous without jq should still block rm -rf \"\$HOME\", got $RC"
run_hook block-dangerous "$(bash_input 'ls')" PATH="$TEST_DIR/badjq:$PATH"
[ "$RC" = 1 ] && [ -s "$ERR" ] || fail "block-dangerous without jq should report exit 1 for a safe command, got $RC"

# --- settings-template: documented hook fields only ---------------------------------------
TEMPLATE="$REPO_DIR/settings-template.json"
jq -e '[.hooks[][].hooks[] | select(has("if"))] | all(.if | test("\\|") | not)' "$TEMPLATE" >/dev/null \
  || fail "settings-template: an 'if' joins rules with | (one permission rule per handler)"
jq -e '[.hooks[][].hooks[] | .timeout // 0] | all(. <= 60)' "$TEMPLATE" >/dev/null \
  || fail "settings-template: timeout is in seconds; keep it <= 60"
jq -e '[.hooks.UserPromptSubmit[].hooks[].command] | index("~/.claude/hooks/plain-words-remind.sh")' "$TEMPLATE" >/dev/null \
  || fail "settings-template: plain-words-remind must stay enabled by default"
jq -e '[.. | .command? // empty] | all(test("prompt-hint") | not)' "$TEMPLATE" >/dev/null \
  || fail "settings-template: retired prompt-hint is bound"

# --- plain-words-remind ------------------------------------------------------------------------
run_hook plain-words-remind '{"prompt":"hi"}'
[ "$RC" = 0 ] || fail "plain-words-remind exit $RC"
jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' "$OUT" >/dev/null || fail "plain-words-remind output"
mkdir -p "$HOME/.claude" && touch "$HOME/.claude/.plain-words-off"
run_hook plain-words-remind '{"prompt":"hi"}'
[ "$RC" = 0 ] && [ ! -s "$OUT" ] || fail "plain-words-remind should be silent when turned off"
rm "$HOME/.claude/.plain-words-off"

# --- legacy vault data: sentinels that must never change ------------------------------------
mkdir -p "$CLAUDE_VAULT_DIR/sessions/pre-compact"
printf '%s\n' 'legacy transcript sentinel' > "$CLAUDE_VAULT_DIR/sessions/pre-compact/transcript-legacy.jsonl"
printf '%s\n' 'legacy log sentinel' > "$CLAUDE_VAULT_DIR/sessions/subagent-activity.log"
printf '%s\n' '1000' > "$CLAUDE_VAULT_DIR/.config-review-stamp"
SENTINELS=(sessions/pre-compact/transcript-legacy.jsonl sessions/subagent-activity.log .config-review-stamp)
(cd "$CLAUDE_VAULT_DIR" && cksum "${SENTINELS[@]}" && find sessions -type f | sort) > "$TEST_DIR/vault-before"
vault_unchanged() {
  (cd "$CLAUDE_VAULT_DIR" && cksum "${SENTINELS[@]}" && find sessions -type f | sort) > "$TEST_DIR/vault-after"
  diff -u "$TEST_DIR/vault-before" "$TEST_DIR/vault-after" >&2 || fail "vault files changed: $1"
}

# --- subagent-stop-log ---------------------------------------------------------------------
LOG="$HOME/.claude/pimp-logs/subagent-activity.log"
printf '%s\n' '{"type":"assistant","text":"Traceback: error in main session"}' > "$TEST_DIR/parent.jsonl"
sub_input() {
  jq -nc --arg t "$TEST_DIR/parent.jsonl" --arg m "$1" \
    '{hook_event_name: "SubagentStop", stop_hook_active: false, agent_id: "a1b2", agent_type: "researcher",
      transcript_path: $t, agent_transcript_path: "/nonexistent", last_assistant_message: $m}'
}
run_hook subagent-stop-log "$(sub_input 'All tests passed. Report: SECRET-BODY-TEXT')"
[ "$RC" = 0 ] || fail "subagent-stop-log exit $RC"
tail -1 "$LOG" | grep -Eq 'agent_type=researcher agent_id=a1b2 hint=none$' \
  || fail "subagent-stop-log should ignore the parent transcript: $(tail -1 "$LOG")"
run_hook subagent-stop-log "$(sub_input 'Error: build failed')"
tail -1 "$LOG" | grep -q 'hint=error-word$' || fail "subagent-stop-log hint: $(tail -1 "$LOG")"
run_hook subagent-stop-log 'not json'
[ "$RC" = 0 ] || fail "subagent-stop-log must exit 0 on malformed input, got $RC"
tail -1 "$LOG" | grep -q 'input-unparsed' || fail "subagent-stop-log malformed line"
run_hook subagent-stop-log "$(jq -nc '{agent_type: "x y;rm", agent_id: "1\n2"}')"
tail -1 "$LOG" | grep -q 'agent_type=x_y_rm agent_id=1_2 hint=none$' || fail "subagent-stop-log must keep one clean line: $(tail -1 "$LOG")"
# An empty value must not shift the next field into its place.
run_hook subagent-stop-log '{"agent_type":"","agent_id":"abc"}'
tail -1 "$LOG" | grep -q 'agent_type=unknown agent_id=abc hint=none$' || fail "subagent-stop-log empty field: $(tail -1 "$LOG")"
grep -q 'SECRET-BODY-TEXT\|build failed' "$LOG" && fail "subagent-stop-log recorded message text"
[ "$(stat -c %a "$LOG" 2>/dev/null || stat -f %Lp "$LOG")" = 600 ] || fail "subagent-stop-log file mode"
run_hook subagent-stop-log "$(sub_input 'ok')" PIMP_MY_LOG_DIR="$TEST_DIR/custom-logs"
test -f "$TEST_DIR/custom-logs/subagent-activity.log" || fail "PIMP_MY_LOG_DIR ignored"
run_hook subagent-stop-log "$(sub_input 'ok')" PIMP_MY_LOG_DIR=/dev/null/nope
[ "$RC" = 0 ] || fail "subagent-stop-log must exit 0 when the log cannot be written, got $RC"
vault_unchanged "subagent-stop-log"

# --- pre-compact-save ----------------------------------------------------------------------
BK="$HOME/.claude/pre-compact-backups"
printf '%s\n' '{"type":"user","text":"transcript body"}' > "$TEST_DIR/session.jsonl"
pc_input() { jq -nc --arg t "$1" '{hook_event_name: "PreCompact", trigger: "auto", transcript_path: $t}'; }
run_hook pre-compact-save "$(pc_input "$TEST_DIR/session.jsonl")"
[ "$RC" = 0 ] || fail "pre-compact-save exit $RC"
run_hook pre-compact-save "$(pc_input "$TEST_DIR/session.jsonl")"
[ "$(find "$BK" -type f | wc -l | tr -d ' ')" = 2 ] || fail "pre-compact-save should keep both backups"
for f in "$BK"/*; do
  cmp -s "$f" "$TEST_DIR/session.jsonl" || fail "pre-compact-save copy differs"
  [ "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" = 600 ] || fail "pre-compact-save file mode"
done
[ "$(stat -c %a "$BK" 2>/dev/null || stat -f %Lp "$BK")" = 700 ] || fail "pre-compact-save dir mode"
# Concurrent calls in the same second each keep their own backup.
printf '%s\n' '{"text":"second session"}' > "$TEST_DIR/session2.jsonl"
for n in 1 2 3 4 5 6 7 8 9 10; do
  CB="$TEST_DIR/concurrent-$n"
  pc_input "$TEST_DIR/session.jsonl" | PIMP_MY_PRE_COMPACT_DIR="$CB" bash "$HOOKS/pre-compact-save.sh" &
  pc_input "$TEST_DIR/session2.jsonl" | PIMP_MY_PRE_COMPACT_DIR="$CB" bash "$HOOKS/pre-compact-save.sh" &
  wait
  [ "$(find "$CB" -type f | wc -l | tr -d ' ')" = 2 ] || fail "pre-compact-save lost a concurrent backup (run $n)"
  cat "$CB"/* | grep -q 'second session' || fail "pre-compact-save concurrent contents"
  cat "$CB"/* | grep -q 'transcript body' || fail "pre-compact-save concurrent contents"
done
# A dangling symlink with the next backup name is never followed; existing files are untouched.
LB="$TEST_DIR/link-backups"
mkdir -p "$LB" "$TEST_DIR/outside"
for s in 0 1 2 3 4 5 6 7 8 9; do
  stamp="$(python3 -I -c 'import sys,time; print(time.strftime("%Y%m%d-%H%M%S", time.localtime(time.time()+int(sys.argv[1]))))' "$s")"
  ln -s "$TEST_DIR/outside/target-$s" "$LB/transcript-$stamp.jsonl"
done
run_hook pre-compact-save "$(pc_input "$TEST_DIR/session.jsonl")" PIMP_MY_PRE_COMPACT_DIR="$LB"
[ "$RC" = 0 ] || fail "pre-compact-save with planted symlinks exit $RC"
[ -z "$(ls "$TEST_DIR/outside")" ] || fail "pre-compact-save followed a dangling symlink"
[ "$(find "$LB" -type f | wc -l | tr -d ' ')" = 1 ] || fail "pre-compact-save should still write one backup"
cmp -s "$(find "$LB" -type f)" "$TEST_DIR/session.jsonl" || fail "pre-compact-save backup next to symlinks differs"
run_hook pre-compact-save "$(pc_input "$TEST_DIR/missing.jsonl")"
[ "$RC" = 0 ] || fail "pre-compact-save with a missing transcript must exit 0"
run_hook pre-compact-save 'not json'
[ "$RC" = 0 ] || fail "pre-compact-save on malformed input must exit 0"
run_hook pre-compact-save "$(pc_input "$TEST_DIR/session.jsonl")" PIMP_MY_PRE_COMPACT_DIR=/dev/null/nope
[ "$RC" = 0 ] || fail "pre-compact-save must exit 0 when the backup cannot be written"
vault_unchanged "pre-compact-save"

# --- vault-briefing: config-review stamp moved out of the vault ----------------------------
brief() { printf '%s' '{"cwd":"/nowhere"}' | bash "$HOOKS/vault-briefing.sh" | jq -r '.hookSpecificOutput.additionalContext'; }
brief | grep -q '\[Config\]' || fail "vault-briefing should still read the legacy stamp when no new one exists"
date +%s > "$HOME/.claude/.config-review-stamp"
brief | grep -q '\[Config\]' && fail "vault-briefing should prefer the new stamp"
printf '%s\n' '1000' > "$HOME/.claude/.config-review-stamp"
brief | grep -q '\[Config\]' || fail "vault-briefing should nudge on an old new-location stamp"
vault_unchanged "vault-briefing"

# --- vault-sync: raw transcripts and hook logs are never committed --------------------------
SYNC_REMOTE="$TEST_DIR/remote.git"
git init --quiet --bare "$SYNC_REMOTE"
git -C "$CLAUDE_VAULT_DIR" init --quiet
git -C "$CLAUDE_VAULT_DIR" remote add origin "$SYNC_REMOTE"
printf '%s\n' 'note' > "$CLAUDE_VAULT_DIR/note.md"
PIMP_MY_VAULT_DIR="$CLAUDE_VAULT_DIR" bash "$REPO_DIR/bin/vault-sync.sh" --commit "test: note" -- note.md >/dev/null 2>&1 \
  || fail "vault-sync should commit a normal note"
HEAD_BEFORE="$(git -C "$CLAUDE_VAULT_DIR" rev-parse HEAD)"
for bad in sessions/pre-compact/transcript-legacy.jsonl ./sessions/pre-compact/transcript-legacy.jsonl \
  Sessions/Pre-Compact/transcript-legacy.jsonl sessions//pre-compact/transcript-legacy.jsonl \
  sessions/subagent-activity.log ./sessions/./subagent-activity.log; do
  if PIMP_MY_VAULT_DIR="$CLAUDE_VAULT_DIR" bash "$REPO_DIR/bin/vault-sync.sh" --commit "test: bad" -- "$bad" >/dev/null 2>"$ERR"; then
    fail "vault-sync accepted $bad"
  fi
  grep -q 'not synced' "$ERR" || fail "vault-sync gave the wrong reason for $bad: $(cat "$ERR")"
done
[ "$(git -C "$CLAUDE_VAULT_DIR" rev-parse HEAD)" = "$HEAD_BEFORE" ] || fail "vault-sync committed after a refusal"
git -C "$CLAUDE_VAULT_DIR" ls-files --error-unmatch sessions/pre-compact/transcript-legacy.jsonl >/dev/null 2>&1 \
  && fail "legacy transcript became tracked"
git -C "$SYNC_REMOTE" ls-tree -r --name-only main | grep -q 'sessions/' && fail "legacy data reached the remote"
vault_unchanged "vault-sync"

echo "hook contracts passed"
