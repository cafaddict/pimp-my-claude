#!/bin/bash
# SubagentStop hook: subagent 종료 이력을 vault 밖 로그에 한 줄씩 남긴다. LLM 호출 없음.
#
# 입력 필드는 agent_type, agent_id, last_assistant_message를 쓴다. transcript_path는
# 부모(main) 세션 transcript라서 subagent 판정에 쓰지 않는다.
# hint=error-word는 마지막 메시지에 실패 단어가 있다는 표시일 뿐 판정이 아니다.
# 메시지 본문은 기록하지 않는다.
# 항상 exit 0 — SubagentStop에서 exit 2를 내면 subagent가 멈추지 않고 계속 돈다.
#
# 위치: ${PIMP_MY_LOG_DIR:-~/.claude/pimp-logs}/subagent-activity.log
#       새로 만든 로그 파일은 600. 이미 있던 파일의 권한은 바꾸지 않는다.
# 예전 위치(vault/sessions/subagent-activity.log)는 읽지도 옮기지도 않는다.

INPUT=$(cat)

LOG_DIR="${PIMP_MY_LOG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/pimp-logs}"
umask 077
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LOG="$LOG_DIR/subagent-activity.log"

FIELDS=$(printf '%s' "$INPUT" | jq -er '
  def clean: tostring | gsub("[^A-Za-z0-9._:@-]"; "_") | if . == "" then "unknown" else . end;
  [ (.agent_type // "unknown" | clean),
    (.agent_id // "unknown" | clean),
    (if ((.last_assistant_message // "") | tostring
         | test("(^|[^A-Za-z])(error|failed|exception|traceback|fatal)([^A-Za-z]|$)"; "i"))
     then "error-word" else "none" end)
  ] | join(" ")' 2>/dev/null) || FIELDS="unknown unknown input-unparsed"

read -r AGENT_TYPE AGENT_ID HINT <<< "$FIELDS"
printf '%s agent_type=%s agent_id=%s hint=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT_TYPE" "$AGENT_ID" "$HINT" >> "$LOG" 2>/dev/null
exit 0
