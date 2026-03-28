#!/bin/bash
# Stop hook: 세션 대화 내용을 요약하여 vault에 저장
# transcript_path에서 대화 내용을 읽고 Claude headless로 요약

VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
SESSIONS_DIR="$VAULT_DIR/sessions"

# vault가 없으면 스킵
[ -d "$VAULT_DIR" ] || exit 0

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
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)

# 백그라운드에서 요약 생성
{
  SUMMARY=""

  # transcript가 있으면 대화 내용 기반 요약
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] && command -v claude &>/dev/null; then
    # transcript에서 대화 내용 추출 (user/assistant 메시지만, 최대 5000자)
    CONVERSATION=$(jq -r '
      [.[] | select(.type == "human" or .type == "assistant") |
       if .type == "human" then "USER: " + (.message // .content // "" | tostring)
       else "ASSISTANT: " + (.message // .content // "" | tostring)
       end
      ] | join("\n\n")' "$TRANSCRIPT_PATH" 2>/dev/null | head -c 5000)

    if [ -n "$CONVERSATION" ]; then
      SUMMARY=$(claude -p "아래는 Claude Code 세션의 대화 내용이다. 이 세션에서 한 작업을 요약해줘.
마크다운 형식으로 간결하게 작성. 반드시 아래 3개 섹션을 포함:

## 작업 내용
(무엇을 했는가 — 핵심만 bullet point로)

## 결정사항
(내린 결정이 있으면 기록, 없으면 '없음')

## 남은 TODO
(미완료 항목이 있으면 체크박스로, 없으면 '없음')

---
대화 내용:
${CONVERSATION}" \
        --max-turns 1 \
        --output-format text \
        2>/dev/null)
    fi
  fi

  # transcript 없거나 요약 실패 시 기본 템플릿
  if [ -z "$SUMMARY" ]; then
    SUMMARY="## 작업 내용
(자동 요약 실패 — /daily 사용 시 현재 세션 내용이 반영됩니다)

## 결정사항


## 남은 TODO
- [ ] "
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
