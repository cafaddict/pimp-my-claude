#!/bin/bash
# PreToolUse hook: Bash 위험 명령 차단
# exit 2 = 차단 (stderr → Claude에 피드백)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

# rm -rf 차단: 루트(/), 홈(~ 단독), 현재디렉토리(. 단독)만 차단
# ~/.claude/skills/foo 같은 정상 경로는 허용
if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|(-[a-zA-Z]*f[a-zA-Z]*r))\s+(/\s|/;|/$|~\s|~;|~$|\.\s|\./?\s|\.;|\.$)'; then
  echo "위험 명령 차단됨 (시스템 경로 삭제): $COMMAND" >&2
  exit 2
fi

# git 위험 명령
if echo "$COMMAND" | grep -qE 'git push (-f |--force)|git reset --hard|git clean -fd'; then
  echo "위험 명령 차단됨 (git): $COMMAND" >&2
  exit 2
fi

# SQL 위험 명령
if echo "$COMMAND" | grep -qiE 'DROP TABLE|DROP DATABASE'; then
  echo "위험 명령 차단됨 (SQL): $COMMAND" >&2
  exit 2
fi
exit 0
