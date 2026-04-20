#!/bin/bash
# PreCompact hook: compaction 직전 transcript를 vault에 백업
# LLM 호출 없음 — 파일 복사만. Non-blocking (exit 0 보장).

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

VAULT="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
BACKUP_DIR="$VAULT/sessions/pre-compact"
mkdir -p "$BACKUP_DIR" 2>/dev/null || exit 0

TS=$(date +%Y%m%d-%H%M%S)
cp "$TRANSCRIPT" "$BACKUP_DIR/transcript-$TS.jsonl" 2>/dev/null
exit 0
