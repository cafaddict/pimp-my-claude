#!/bin/bash
# Stop hook: 세션 요약을 vault에 자동 저장
# vault 경로는 환경변수 또는 기본값 사용

VAULT_DIR="${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}"
SESSIONS_DIR="$VAULT_DIR/sessions"

# vault가 없으면 스킵
[ -d "$VAULT_DIR" ] || exit 0

mkdir -p "$SESSIONS_DIR"

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M)
SESSION_FILE="$SESSIONS_DIR/${DATE}-${TIME}.md"

# 이미 같은 파일이 있으면 번호 추가
if [ -f "$SESSION_FILE" ]; then
  SESSION_FILE="$SESSIONS_DIR/${DATE}-${TIME}-$(date +%S).md"
fi

# stdin에서 세션 정보 읽기 (Stop hook은 stdin으로 JSON 받음)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"' 2>/dev/null)

# 세션 기록 파일 생성
cat > "$SESSION_FILE" << EOF
---
date: ${DATE}
tags: [session]
session_id: ${SESSION_ID}
cwd: ${CWD}
---

# 세션: ${DATE} ${TIME}

> 이 노트는 자동 생성되었습니다. 필요시 수동으로 작업 내용, 결정사항, TODO를 추가하세요.

## 작업 디렉토리
\`${CWD}\`

## 작업 내용


## 결정사항


## 남은 TODO
- [ ]

EOF

exit 0
