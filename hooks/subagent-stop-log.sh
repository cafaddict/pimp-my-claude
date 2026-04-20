#!/bin/bash
# SubagentStop hook: 서브에이전트 종료 시 실패 감지 + vault 로그
# LLM 호출 없음 — grep 기반 패턴 매칭. Non-blocking.

INPUT=$(cat)
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

VAULT="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
LOG="$VAULT/sessions/subagent-activity.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0

STATUS="ok"
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # 실패 시그널 패턴 탐지 — word boundary로 오탐 방지
  if grep -qiE '(^|[^a-zA-Z])(error|failed|exception|traceback|fatal)([^a-zA-Z]|$)' "$TRANSCRIPT" 2>/dev/null; then
    STATUS="error"
  fi
fi

echo "$(date -Iseconds) $AGENT_NAME ($AGENT_ID) $STATUS" >> "$LOG" 2>/dev/null
exit 0
