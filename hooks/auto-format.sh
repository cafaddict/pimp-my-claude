#!/bin/bash
# PostToolUse hook: 파일 편집 후 자동 포맷팅
# Claude가 포맷에 토큰을 쓰지 않아도 됨

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.py)                          black "$FILE_PATH" 2>/dev/null || ruff format "$FILE_PATH" 2>/dev/null ;;
  *.rs)
    # Edition-aware: rustfmt's import-sort heuristic differs across
    # 2021/2024, so hook output must match the file's owning crate.
    # Walk up from FILE_PATH to find the nearest Cargo.toml; default to
    # 2024 (current stable) when none is found.
    rs_edition="2024"
    rs_dir=$(dirname "$FILE_PATH")
    while [ "$rs_dir" != "/" ] && [ "$rs_dir" != "." ]; do
      if [ -f "$rs_dir/Cargo.toml" ]; then
        rs_edition=$(grep -m1 '^edition' "$rs_dir/Cargo.toml" 2>/dev/null \
          | sed -E 's/.*"([0-9]+)".*/\1/' \
          | grep -E '^[0-9]+$' || echo "2024")
        break
      fi
      rs_dir=$(dirname "$rs_dir")
    done
    rustfmt --edition "$rs_edition" "$FILE_PATH" 2>/dev/null ;;
  *.cpp|*.hpp|*.c|*.h|*.cc)     clang-format -i "$FILE_PATH" 2>/dev/null ;;
  *.ts|*.tsx|*.js|*.jsx|*.json)  prettier --write "$FILE_PATH" 2>/dev/null ;;
  *.css|*.scss)                  prettier --write "$FILE_PATH" 2>/dev/null ;;
esac
exit 0
