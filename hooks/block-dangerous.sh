#!/bin/bash
# PreToolUse hook: Bash 위험 명령 차단
# exit 2 = 차단 (stderr → Claude에 피드백)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

if echo "$COMMAND" | grep -qE 'rm -rf[[:space:]]+(\/|~|\.)|git push (-f |--force)|git reset --hard|git clean -fd|DROP TABLE|DROP DATABASE'; then
  echo "위험 명령 차단됨: $COMMAND" >&2
  exit 2
fi
exit 0
