#!/bin/bash
# UserPromptSubmit hook: plain-words 상시 모드 (기본 켜짐)
#
# 끄기: touch ~/.claude/.plain-words-off
# 켜기: rm ~/.claude/.plain-words-off
#
# 왜 훅인가: rule/CLAUDE.md는 세션 시작에 한 번 로드되므로 긴 대화에서 드리프트하고,
# compaction 때 잘려 나간다. 매 턴 짧게 재주입하면 그 드리프트가 잡힌다.
# 단어 선택은 요청받고 하는 작업이 아니라 상시 습관이므로 기본 켜짐이 맞다.
# 비용: 아래 문자열 176자 (ASCII 104 + 한글 72) — 대략 100~150 토큰. 측정값 아닌 추정.
# 코딩 위주 세션에서 노이즈로 느껴지면 위 플래그로 끈다.

cat >/dev/null  # stdin(hook payload) 소비

[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.plain-words-off" ] && exit 0

cat <<'EOF'
{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "plain-words: 산문은 실무자가 말하는 표현으로 (유휴→idle, 축출→evict, 이질적→서로 다른, utilize→use). 정착된 용어는 그대로 (queue, TTFT, threshold, backpressure) — 억지 번역 금지. 기준: 회의에서 소리 내어 말하는 단어인가. 코드·에러·인용 제외."}}
EOF
exit 0
