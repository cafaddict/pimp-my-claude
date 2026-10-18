#!/bin/bash
# Keep a personal vault current without discarding local work.
# Usage:
#   vault-sync.sh --pull
#   vault-sync.sh --commit "note: title" -- path/to/note.md [path/to/other.md ...]
#
# --commit records and pushes only the listed vault-relative files. Other staged,
# unstaged, and untracked changes stay local with their staged state intact.
# The script stops instead of guessing when another sync holds the lock, a merge or
# rebase is in progress, restoring local changes conflicts, or the push would also
# publish local commits that this run did not create.

set -euo pipefail

usage() {
  echo "Usage: vault-sync.sh --pull | --commit <message> -- <vault-relative-file...>" >&2
  exit 2
}

fail() {
  echo "vault sync stopped: $*" >&2
  exit 1
}

MODE=""
MESSAGE=""
if [ "${1:-}" = "--pull" ]; then
  MODE="pull"
  shift
elif [ "${1:-}" = "--commit" ] && [ -n "${2:-}" ]; then
  MODE="commit"
  MESSAGE="$2"
  shift 2
  [ "${1:-}" = "--" ] || usage
  shift
  [ "$#" -gt 0 ] || usage
else
  usage
fi

VAULT_DIR="${PIMP_MY_VAULT_DIR:-${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}}"
[ -d "$VAULT_DIR/.git" ] || {
  echo "vault sync skipped: not a git repository ($VAULT_DIR)" >&2
  exit 0
}

cd "$VAULT_DIR"
# Commands that take the caller's paths treat them as literal file names: no globs,
# no ":(top)" style magic. Do not export GIT_LITERAL_PATHSPECS for the whole script:
# it stops `git stash push --include-untracked` from removing the files it saved.
LITERAL=(git --literal-pathspecs)

# Validate every path before touching the repository.
if [ "$MODE" = "commit" ]; then
  for path in "$@"; do
    case "$path" in
      ''|/*) fail "path must be relative to the vault: '$path'" ;;
    esac
    lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
    IFS='/' read -r -a parts <<< "$lower"
    for part in "${parts[@]}"; do
      case "$part" in
        ..) fail "path must stay inside the vault: '$path'" ;;
        .git) fail "path must not point into .git: '$path'" ;;
      esac
    done
    if [ -L "$path" ] || [ -f "$path" ]; then
      :
    elif [ -e "$path" ]; then
      fail "only individual files can be synced, not directories: '$path'"
    elif ! "${LITERAL[@]}" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      fail "file not found in the vault: '$path'"
    fi
  done
fi

LOCK_DIR="$(git rev-parse --git-path pimp-vault-sync.lock)"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail "another vault sync is running. If none is, remove the stale lock: rmdir '$VAULT_DIR/$LOCK_DIR'"
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  if [ -e "$(git rev-parse --git-path "$state")" ]; then
    fail "a merge or rebase is in progress in $VAULT_DIR; finish or abort it first."
  fi
done
if [ -n "$(git ls-files --unmerged)" ]; then
  fail "unresolved conflicts exist in $VAULT_DIR; resolve them first."
fi

BRANCH="$(git branch --show-current)"
HAS_HEAD=false
if git rev-parse --verify --quiet HEAD >/dev/null; then
  HAS_HEAD=true
fi
HAS_REMOTE=false
if git remote get-url origin >/dev/null 2>&1; then
  HAS_REMOTE=true
fi
if [ "$MODE" = "commit" ] && [ "$HAS_REMOTE" = true ] && [ -z "$BRANCH" ]; then
  fail "HEAD is detached in $VAULT_DIR; check out a branch first."
fi

# Protect local work. The stash is tracked by its commit id, not by stash@{N},
# so stashes made by anything else cannot be confused with this one.
STASH_SHA=""
if [ "$HAS_HEAD" = true ] && { ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; }; then
  BEFORE="$(git rev-parse --verify --quiet refs/stash || true)"
  git stash push --include-untracked -m "pimp-my-claude auto-sync $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >/dev/null
  AFTER="$(git rev-parse --verify --quiet refs/stash || true)"
  [ -n "$AFTER" ] && [ "$AFTER" != "$BEFORE" ] && STASH_SHA="$AFTER"
fi

stash_entry() {
  git stash list --format='%gd %H' | awk -v sha="$STASH_SHA" '$2 == sha { print $1; exit }'
}

# `git stash apply --index` can fail after restoring nothing (staged changes overlap
# the pulled notes) or only part (an untracked note has the same path as a pulled
# file). The stash then holds the only full copy, so list every saved path that
# does not match it and never suggest dropping the stash.
restore_failed() {
  local s="$STASH_SHA" p saved now missing=()
  while IFS= read -r -d '' p; do
    saved="$(git rev-parse -q --verify "$s:$p" 2>/dev/null || true)"
    now=""
    if [ -f "$p" ] || [ -L "$p" ]; then now="$(git hash-object -- "$p" 2>/dev/null || true)"; fi
    [ "$saved" = "$now" ] || missing+=("working tree: $p  (saved copy: git show '$s:$p')")
  done < <(git diff -z --name-only --no-renames "$s^1" "$s")
  while IFS= read -r -d '' p; do
    saved="$(git rev-parse -q --verify "$s^2:$p" 2>/dev/null || true)"
    now="$(git rev-parse -q --verify ":0:$p" 2>/dev/null || true)"
    [ "$saved" = "$now" ] || missing+=("staged: $p  (saved copy: git show '$s^2:$p')")
  done < <(git diff -z --name-only --no-renames "$s^1" "$s^2")
  if git rev-parse -q --verify "$s^3" >/dev/null; then
    while IFS= read -r -d '' p; do
      saved="$(git rev-parse "$s^3:$p")"
      now=""
      if [ -f "$p" ] || [ -L "$p" ]; then now="$(git hash-object -- "$p" 2>/dev/null || true)"; fi
      [ "$saved" = "$now" ] || missing+=("untracked: $p  (saved copy: git show '$s^3:$p')")
    done < <(git ls-tree -r -z --name-only "$s^3")
  fi
  {
    echo "vault sync stopped: the pull finished, but local changes could not be fully restored. Nothing was committed or pushed."
    echo "All staged, unstaged, and untracked changes from before the sync are still saved in $(stash_entry) ($s)."
    echo "Do NOT drop or clear this stash until you have recovered every change and checked it against the stash; it may be the only copy."
    if [ "${#missing[@]}" -gt 0 ]; then
      echo "Not restored, conflicted, or different from the saved copy:"
      printf '  %s\n' "${missing[@]}"
    fi
    if [ -n "$(git ls-files --unmerged)" ]; then
      echo "Files with conflict markers: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
    fi
    echo "See everything that is saved: git stash show --include-untracked --name-status $s"
    echo "To keep both versions, write a saved copy beside the current file instead of over it, e.g. git show '<saved copy>' > '<path>.local'"
  } >&2
  exit 1
}

if [ "$HAS_REMOTE" = true ]; then
  if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    PULL_ARGS=(git pull --rebase)
  elif [ -n "$BRANCH" ] && git ls-remote --exit-code --heads origin "refs/heads/$BRANCH" >/dev/null 2>&1; then
    PULL_ARGS=(git pull --rebase origin "$BRANCH")
  else
    PULL_ARGS=()
  fi
  if [ "${#PULL_ARGS[@]}" -gt 0 ] && ! "${PULL_ARGS[@]}"; then
    if [ -n "$STASH_SHA" ]; then
      fail "pull --rebase failed; local changes are kept in $(stash_entry) ($STASH_SHA). After fixing the pull, restore them with: git stash pop --index '$(stash_entry)'"
    fi
    fail "pull --rebase failed; nothing was committed or pushed."
  fi
fi

# Restore staged changes as staged and the rest as they were.
if [ -n "$STASH_SHA" ]; then
  if ! git stash apply --index "$STASH_SHA" >/dev/null; then
    restore_failed
  fi
  git stash drop --quiet "$(stash_entry)"
fi

[ "$MODE" = "commit" ] || exit 0

# Push only the commit made below. Earlier unpushed commits need a human decision.
PUSH=false
if [ "$HAS_REMOTE" = true ]; then
  PUSH=true
  if UPSTREAM="$(git rev-parse --verify --quiet '@{upstream}')"; then
    BASE="$UPSTREAM"
  elif BASE="$(git rev-parse --verify --quiet "refs/remotes/origin/$BRANCH")"; then
    :
  else
    BASE=""
  fi
  if git rev-parse --verify --quiet HEAD >/dev/null; then
    if [ -n "$BASE" ]; then
      AHEAD="$(git rev-list --count "$BASE..HEAD")"
    else
      AHEAD="$(git rev-list --count HEAD)"
    fi
    if [ "$AHEAD" != "0" ]; then
      fail "$AHEAD local commit(s) on '$BRANCH' are not on origin yet. Review and push them yourself (git push -u origin '$BRANCH'), then run the sync again. Your note is unchanged and uncommitted."
    fi
  fi
fi

"${LITERAL[@]}" add -- "$@"
if "${LITERAL[@]}" diff --cached --quiet -- "$@"; then
  echo "vault sync: no changes in the listed files" >&2
  exit 0
fi
# --only commits exactly these paths; any other staged entries stay staged.
"${LITERAL[@]}" commit --quiet --only -m "$MESSAGE" -- "$@"

if [ "$PUSH" = true ] && ! git push --quiet -u origin "$BRANCH"; then
  fail "push failed; the note is committed locally on '$BRANCH'. Run 'git pull --rebase && git push' in $VAULT_DIR after checking the remote."
fi
