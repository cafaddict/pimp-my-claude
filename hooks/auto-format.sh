#!/bin/bash
# PostToolUse hook: 파일 편집 후 자동 포맷팅
# Claude가 포맷에 토큰을 쓰지 않아도 됨

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.py)                          black "$FILE_PATH" 2>/dev/null || ruff format "$FILE_PATH" 2>/dev/null ;;
  *.cpp|*.hpp|*.c|*.h|*.cc)     clang-format -i "$FILE_PATH" 2>/dev/null ;;
  *.ts|*.tsx|*.js|*.jsx|*.json)  prettier --write "$FILE_PATH" 2>/dev/null ;;
  *.css|*.scss)                  prettier --write "$FILE_PATH" 2>/dev/null ;;
esac
exit 0
