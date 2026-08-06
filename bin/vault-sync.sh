#!/bin/bash
# Keep a personal vault current without discarding local work.
# Usage:
#   vault-sync.sh --pull
#   vault-sync.sh --commit "note: title" -- path/to/note.md [path/to/other.md ...]

set -euo pipefail

usage() {
  echo "Usage: vault-sync.sh --pull | --commit <message> -- <vault-relative-path...>" >&2
  exit 2
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
STASHED=false
STASH_REF=""
HAS_HEAD=false
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  HAS_HEAD=true
fi
if [ "$HAS_HEAD" = true ] && { ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; }; then
  git stash push --include-untracked -m "pimp-my-claude auto-sync $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >/dev/null
  STASHED=true
  STASH_REF="$(git stash list -1 --format='%gd')"
fi

if git remote get-url origin >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current)"
  if git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    PULL_ARGS=(git pull --rebase)
  elif [ -n "$BRANCH" ] && git ls-remote --exit-code --heads origin "refs/heads/$BRANCH" >/dev/null 2>&1; then
    PULL_ARGS=(git pull --rebase origin "$BRANCH")
  else
    PULL_ARGS=()
  fi
  if [ "${#PULL_ARGS[@]}" -gt 0 ] && ! "${PULL_ARGS[@]}"; then
    echo "vault sync stopped: pull --rebase failed; local changes remain protected in $STASH_REF. Recover with: git stash pop '$STASH_REF'" >&2
    exit 1
  fi
fi

if [ "$STASHED" = true ] && ! git stash pop "$STASH_REF"; then
  echo "vault sync stopped: stash restore conflicted; resolve the conflict, then finish restoring $STASH_REF." >&2
  exit 1
fi

if [ "$MODE" = "commit" ]; then
  git add -- "$@"
  if ! git diff --cached --quiet; then
    git commit -m "$MESSAGE"
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    git push -u origin HEAD
  fi
fi
