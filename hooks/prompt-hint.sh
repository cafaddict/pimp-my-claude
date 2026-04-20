#!/bin/bash
# UserPromptSubmit hook: 모호한 프롬프트에 컨텍스트 힌트 주입 (차단 아님)
# 질문형/긴 프롬프트는 통과. 짧고 선언적인 프롬프트에만 힌트 추가.

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
LEN=${#PROMPT}

# 매우 짧고 모호 (20자 미만, 질문/의문형 키워드 없음)
if [ "$LEN" -lt 20 ] && ! echo "$PROMPT" | grep -qE '\?|어떻게|왜|뭐|무엇|어디|언제|what|why|how|where|when'; then
  cat <<'EOF'
{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "사용자 프롬프트가 짧고 모호합니다. Task/Context/Requirements/Output 구조로 의도를 해석하되, 확신이 없으면 명확화 질문을 먼저 하세요."}}
EOF
fi
exit 0
