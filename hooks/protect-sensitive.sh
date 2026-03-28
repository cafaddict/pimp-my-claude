#!/bin/bash
# PreToolUse hook: 민감 파일 수정 차단
# .env, credentials, secrets, 키 파일 등

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")

if echo "$BASENAME" | grep -qiE '^\.env($|\.)|^credentials\.|^secrets?\.|\.pem$|\.key$|^id_rsa|^id_ed25519'; then
  echo "민감 파일 수정 차단: $FILE_PATH" >&2
  exit 2
fi
exit 0
