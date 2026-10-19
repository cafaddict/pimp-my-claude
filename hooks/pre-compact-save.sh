#!/bin/bash
# PreCompact hook: compaction 직전 원본 transcript를 vault 밖에 백업한다. LLM 호출 없음.
#
# Claude Code는 세션 파일을 cleanupPeriodDays(기본 30일) 뒤 지우므로 이 백업만 오래 남는다.
# transcript에는 대화 전체가 들어 있으니 git으로 관리하는 vault에 두지 않는다.
# 위치: ${PIMP_MY_PRE_COMPACT_DIR:-~/.claude/pre-compact-backups} (새로 만든 디렉터리 700, 파일 600.
#       이미 있던 디렉터리의 권한은 바꾸지 않는다)
# 예전 위치(vault/sessions/pre-compact/)의 파일은 건드리지 않는다.
# 항상 exit 0 — PreCompact에서 exit 2를 내면 compaction이 막힌다.

INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
{ [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0

BACKUP_DIR="${PIMP_MY_PRE_COMPACT_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/pre-compact-backups}"
umask 077
if [ ! -d "$BACKUP_DIR" ]; then
  mkdir -p "$BACKUP_DIR" 2>/dev/null || exit 0
  chmod 700 "$BACKUP_DIR" 2>/dev/null
fi

# 같은 이름이 이미 있으면(동시 호출, 남아 있는 symlink 포함) 쓰지 않고 다음 이름을 쓴다.
# noclobber(set -C)는 O_EXCL로 새 파일만 만들므로 기존 파일·symlink 대상을 덮어쓰지 않는다.
[ -r "$TRANSCRIPT" ] || exit 0
STAMP="$(date +%Y%m%d-%H%M%S)"
set -C
for SUFFIX in "" "-$$" "-$$-$RANDOM" "-$$-$RANDOM-$RANDOM"; do
  OPENED=false
  { OPENED=true; cat "$TRANSCRIPT" >&3; } 2>/dev/null 3> "$BACKUP_DIR/transcript-$STAMP$SUFFIX.jsonl"
  [ "$OPENED" = true ] && break
done
exit 0
