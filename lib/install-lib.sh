# shellcheck shell=bash
# Shared by setup.sh and setup-codex.sh (sourced, not executed).
#
# Re-running an installer must not overwrite what the user changed. An installed copy is
# replaced only when it is missing, already current, or byte-identical to a version this
# repository shipped before (found in git history, after the same rendering). Anything
# else is a local edit: it is kept and reported. Installed files are never deleted: a
# retired skill that still matches a shipped version is moved to a backup directory, and a
# global instructions file is copied to a backup before it is replaced by a vault link.

PIMP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIMP_REPO_DIR="$(cd "$PIMP_LIB_DIR/.." && pwd)"

# Escape text for the replacement side of `sed s|...|...|`.
pimp_sed_repl() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }

# pimp_was_shipped <repo-path> <installed-file> [render-command...]
# True if the installed file equals some committed version of repo-path, rendered by
# the given command (stdin -> stdout; default: unchanged).
pimp_was_shipped() {
  local path="$1" file="$2" blob
  shift 2
  [ "$#" -gt 0 ] || set -- cat
  git -C "$PIMP_REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 1
  while IFS= read -r blob; do
    if git -C "$PIMP_REPO_DIR" cat-file blob "$blob" 2>/dev/null | "$@" | cmp -s - "$file"; then
      return 0
    fi
  done < <(git -C "$PIMP_REPO_DIR" log --all --no-abbrev --format= --raw -- "$path" 2>/dev/null \
             | awk '$4 !~ /^0+$/ { print $4 }' | sort -u)
  return 1
}

# pimp_classify <new-file> <installed-file> <repo-path> [render-command...]
# Prints one of: missing | current | shipped (an older version we shipped) | modified
pimp_classify() {
  local new="$1" dest="$2" path="$3"
  shift 3
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then echo missing
  elif cmp -s "$new" "$dest"; then echo current
  elif [ -L "$dest" ]; then echo modified   # a symlink the user set up (e.g. to dotfiles): never replace it
  elif [ -f "$dest" ] && pimp_was_shipped "$path" "$dest" "$@"; then echo shipped
  else echo modified
  fi
}

# pimp_install_file <new-file> <dest> <mode>   (atomic replace; mode e.g. 755 or 644)
pimp_install_file() {
  local tmp
  tmp="$(mktemp "$(dirname "$2")/.pimp-install.XXXXXX")"
  cp "$1" "$tmp"
  chmod "$3" "$tmp"
  mv -f "$tmp" "$2"
}

# pimp_known_handlers <repo-path> [render-command...] -> JSON [{event, handler}] from
# every committed version of a hook template plus the working-tree copy.
pimp_known_handlers() {
  local path="$1" commit
  shift
  [ "$#" -gt 0 ] || set -- cat
  {
    if git -C "$PIMP_REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "$PIMP_REPO_DIR" log --all --format=%H -- "$path" 2>/dev/null | while IFS= read -r commit; do
        git -C "$PIMP_REPO_DIR" show "$commit:$path" 2>/dev/null | "$@"
      done
    fi
    "$@" < "$PIMP_REPO_DIR/$path"
  } | jq -s '[ .[] | objects | (.hooks // {}) | objects | to_entries[] | .key as $e
               | (.value | arrays)[] | (.hooks // [])[] | {event: $e, handler: .} ] | unique'
}

# pimp_merge_hooks <existing> <template> <mode> <known-json> <retired-json> <out-settings> <out-report>
pimp_merge_hooks() {
  local result
  result="$(jq -s --arg mode "$3" --argjson known "$4" --argjson retired "$5" --arg home "$HOME" \
    -f "$PIMP_LIB_DIR/hooks-merge.jq" "$1" "$2")" || return 1
  printf '%s\n' "$result" | jq '.settings' > "$6" || return 1
  printf '%s\n' "$result" | jq '.report' > "$7" || return 1
}

# pimp_hooks_readable <existing> <template> — true if the merge rules understand the file.
# Run before writing anything so a bad structure stops the installer with no changes.
pimp_hooks_readable() {
  jq -s --arg mode merge --argjson known '[]' --argjson retired '[]' --arg home "$HOME" \
    -f "$PIMP_LIB_DIR/hooks-merge.jq" "$1" "$2" >/dev/null 2>&1
}

# pimp_shell_safe_path <path> — true if the path can be written unquoted into a shell
# command (hook "command", code lines in SKILL.md). Spaces and shell metacharacters are
# refused instead of rendering commands that would split or run path fragments.
pimp_shell_safe_path() {
  case "$1" in
    *[[:space:]\'\"\\\$\`\;\&\|\<\>\(\)\*\?\[\]\{\}\!\#]*) return 1 ;;
  esac
  return 0
}

# pimp_print_report <report-json>
pimp_print_report() {
  jq -r '
    def show($title; $xs): if ($xs | length) > 0 then "  \($title):", ($xs[] | "    - \(.)") else empty end;
    show("추가"; .added), show("교체(배포했던 예전 정의)"; .replaced),
    show("중복 제거"; .removed), show("바인딩 해제(retired, 파일은 유지)"; .unbound),
    show("보류(사용자가 고친 정의 — 직접 검토)"; .conflicts),
    show("템플릿과 다름(--upgrade-hooks로 검토)"; .differs)' "$1"
}

# pimp_same_json <a> <b> — true if both files hold the same JSON value.
pimp_same_json() { [ "$(jq -S . "$1")" = "$(jq -S . "$2")" ]; }

# pimp_new_backup_dir <parent> -> creates and prints a fresh, never-reused directory.
pimp_new_backup_dir() {
  local base n=0 dir
  base="$1/$(date -u +%Y%m%dT%H%M%SZ)"
  dir="$base"
  mkdir -p "$1"
  until mkdir "$dir" 2>/dev/null; do
    n=$((n + 1))
    [ "$n" -lt 100 ] || return 1
    dir="$base-$n"
  done
  chmod 700 "$dir"
  printf '%s\n' "$dir"
}

# pimp_user_config_state <vault-file> <dest>
# Prints one of: absent (no vault copy) | linked (dest already points at it) |
# other-link (a symlink to something else, or broken) | missing | same | differs
pimp_user_config_state() {
  local src="$1" dest="$2"
  if [ ! -f "$src" ]; then echo absent
  elif [ -L "$dest" ] && [ "$dest" -ef "$src" ]; then echo linked
  elif [ -L "$dest" ]; then echo other-link
  elif [ ! -e "$dest" ]; then echo missing
  elif cmp -s "$src" "$dest"; then echo same
  else echo differs
  fi
}

# pimp_install_symlink <target> <dest>   (atomic replace of a file by a symlink)
pimp_install_symlink() {
  local tmp
  tmp="$(dirname "$2")/.pimp-link.$$"
  ln -s "$1" "$tmp"
  # mv onto a symlink to a directory would move into that directory; drop the old link first.
  if [ -L "$2" ]; then rm -f "$2"; fi
  mv -f "$tmp" "$2"
}
