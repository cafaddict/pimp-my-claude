#!/bin/bash
# statusLine: JSON stdin → 한 줄 출력
# 형식: <model> · ctx N% · vault: Xd/Yl · <branch>
# 빠르게 끝나야 함 — heavy command 금지 (네트워크/빌드 명령 X).

INPUT=$(cat)
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "claude"' 2>/dev/null)
CTX_PCT=$(echo "$INPUT" | jq -r '.context_percent // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null)

VAULT="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
DEC=0
LES=0
if [ -d "$VAULT/decisions" ]; then
  DEC=$(find "$VAULT/decisions" -maxdepth 3 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ -d "$VAULT/lessons" ]; then
  LES=$(find "$VAULT/lessons" -maxdepth 3 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

BRANCH=""
if [ -n "$CWD" ] && [ -d "$CWD/.git" ]; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi

OUT="$MODEL"
if [ -n "$CTX_PCT" ]; then
  OUT="$OUT · ctx ${CTX_PCT}%"
fi
OUT="$OUT · vault ${DEC}d/${LES}l"
if [ -n "$BRANCH" ]; then
  OUT="$OUT · $BRANCH"
fi

echo "$OUT"
