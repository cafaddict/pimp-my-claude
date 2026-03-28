#!/bin/bash
# Stop hook: 세션 요약을 vault에 자동 저장
# Claude headless로 세션 내용 요약 생성

VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
SESSIONS_DIR="$VAULT_DIR/sessions"

# vault가 없으면 스킵
[ -d "$VAULT_DIR" ] || exit 0

# claude CLI가 없으면 스킵
command -v claude &>/dev/null || exit 0

mkdir -p "$SESSIONS_DIR"

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M)
SESSION_FILE="$SESSIONS_DIR/${DATE}-${TIME}.md"

if [ -f "$SESSION_FILE" ]; then
  SESSION_FILE="$SESSIONS_DIR/${DATE}-${TIME}-$(date +%S).md"
fi

# stdin에서 세션 정보 읽기
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"' 2>/dev/null)

# Claude headless로 세션 요약 생성 (백그라운드)
{
  SUMMARY=$(claude -p "이번 세션에서 한 작업, 결정사항, 남은 TODO를 간결하게 요약해줘. 마크다운 형식으로. 섹션: 작업 내용, 결정사항, 남은 TODO" \
    --max-turns 1 \
    --output-format text \
    -r "$SESSION_ID" \
    2>/dev/null)

  # 요약이 비어있으면 기본 템플릿
  if [ -z "$SUMMARY" ]; then
    SUMMARY="(요약 생성 실패 — 수동으로 내용을 추가하세요)"
  fi

  cat > "$SESSION_FILE" << EOF
---
date: ${DATE}
tags: [session]
session_id: ${SESSION_ID}
cwd: ${CWD}
---

# 세션: ${DATE} ${TIME}

## 작업 디렉토리
\`${CWD}\`

${SUMMARY}
EOF

  # git commit + push
  if [ -d "$VAULT_DIR/.git" ]; then
    cd "$VAULT_DIR"
    git add sessions/ 2>/dev/null
    git commit -m "session: ${DATE} ${TIME}" --quiet 2>/dev/null || true
    git push --quiet 2>/dev/null || true
  fi
} &

exit 0
