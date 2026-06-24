#!/bin/bash
# SessionStart hook: vault 브리핑 (경량 컨텍스트 로딩)
# < 1초 목표. git/네트워크 호출 금지. find/grep/head만 사용.

INPUT=$(cat)

VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"

# vault 없으면 빈 출력 후 종료
if [ ! -d "$VAULT_DIR" ]; then
  echo '{}'
  exit 0
fi

# --- 통계 수집 ---

count_md() {
  find "$1" -maxdepth 1 -name "*.md" ! -name ".gitkeep" ! -name "CLAUDE.md" 2>/dev/null | wc -l | tr -d ' '
}

DECISION_COUNT=$(count_md "$VAULT_DIR/decisions")
LESSON_COUNT=$(count_md "$VAULT_DIR/lessons")
SESSION_COUNT=$(count_md "$VAULT_DIR/sessions")
RESOURCE_COUNT=$(count_md "$VAULT_DIR/resources")
# projects/areas는 재귀 탐색
PROJECT_COUNT=$(find "$VAULT_DIR/projects" -name "*.md" ! -name ".gitkeep" ! -name "CLAUDE.md" 2>/dev/null | wc -l | tr -d ' ')

STATS="Vault: 결정 ${DECISION_COUNT}개, 교훈 ${LESSON_COUNT}개, 세션 ${SESSION_COUNT}개, 프로젝트 ${PROJECT_COUNT}개, 리소스 ${RESOURCE_COUNT}개"

# --- 최근 세션의 미완료 TODO ---

TODOS=""
LATEST_SESSION=$(ls -t "$VAULT_DIR/sessions/"*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SESSION" ]; then
  SESSION_NAME=$(basename "$LATEST_SESSION" .md)
  TODO_LINES=$(grep -E '^\s*- \[ \]' "$LATEST_SESSION" 2>/dev/null | head -5 | sed 's/^[[:space:]]*/  /')
  if [ -n "$TODO_LINES" ]; then
    TODOS="미완료 TODO (from [[${SESSION_NAME}]]):\n${TODO_LINES}"
  fi
fi

# --- 최근 교훈 3개 (제목만) ---

LESSONS=""
LESSON_FILES=$(ls -t "$VAULT_DIR/lessons/"*.md 2>/dev/null | head -3)
if [ -n "$LESSON_FILES" ]; then
  LESSON_LIST=""
  while IFS= read -r f; do
    TITLE=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //')
    FNAME=$(basename "$f" .md)
    if [ -n "$TITLE" ]; then
      LESSON_LIST="${LESSON_LIST}  - [[${FNAME}]] ${TITLE}\n"
    fi
  done <<< "$LESSON_FILES"
  if [ -n "$LESSON_LIST" ]; then
    LESSONS="최근 교훈:\n${LESSON_LIST}"
  fi
fi

# --- 현재 프로젝트 컨텍스트 ---

PROJECT_CTX=""
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -n "$CWD" ]; then
  PROJECT_NAME=$(basename "$CWD")
  PROJECT_FILE="$VAULT_DIR/projects/${PROJECT_NAME}.md"
  if [ -f "$PROJECT_FILE" ]; then
    PROJECT_CTX="현재 프로젝트: [[${PROJECT_NAME}]] (vault에 프로젝트 노트 있음)"
  fi
fi

# --- config 점검 staleness 넛지 (분기 백스톱) ---
# /config-review가 갱신하는 마커 파일 기준. date 산술만, 네트워크/git 무호출.
# 임계 미만이면 완전 침묵(over-nag 방지). 기본 90일 = 분기(커뮤니티 관행 기본값).

CONFIG_NUDGE=""
STAMP="$VAULT_DIR/.config-review-stamp"
THRESH="${CLAUDE_CONFIG_REVIEW_DAYS:-90}"
if [ "$THRESH" -gt 0 ] 2>/dev/null; then
  if [ -f "$STAMP" ]; then
    LAST=$(cat "$STAMP" 2>/dev/null)
    if [ -n "$LAST" ] 2>/dev/null && [ "$LAST" -gt 0 ] 2>/dev/null; then
      AGE_DAYS=$(( ( $(date +%s) - LAST ) / 86400 ))
      if [ "$AGE_DAYS" -ge "$THRESH" ]; then
        CONFIG_NUDGE="[Config] 마지막 설정 점검 ${AGE_DAYS}일 전 — /config-review 권장 (분기 백스톱)."
      fi
    fi
  fi
fi

# --- 브리핑 조합 ---

BRIEFING="[Vault Briefing]\n${STATS}"

[ -n "$PROJECT_CTX" ] && BRIEFING="${BRIEFING}\n${PROJECT_CTX}"
[ -n "$TODOS" ] && BRIEFING="${BRIEFING}\n${TODOS}"
[ -n "$LESSONS" ] && BRIEFING="${BRIEFING}\n${LESSONS}"
[ -n "$CONFIG_NUDGE" ] && BRIEFING="${BRIEFING}\n${CONFIG_NUDGE}"

BRIEFING="${BRIEFING}\n/vault-search [keyword]로 vault 검색 가능. /vault-recall [keyword]로 세션 복원 가능."

# --- JSON 출력 (jq로 안전한 이스케이핑) ---

if command -v jq &>/dev/null; then
  echo '{}' | jq --arg ctx "$(echo -e "$BRIEFING")" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  # jq 없으면 빈 출력
  echo '{}'
fi

exit 0
