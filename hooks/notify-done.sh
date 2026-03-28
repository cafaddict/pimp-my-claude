#!/bin/bash
# Stop hook: 작업 완료 알림 (크로스 플랫폼)

case "$(uname -s)" in
  Darwin)
    osascript -e 'display notification "Claude 작업 완료" with title "Claude Code" sound name "Glass"'
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send "Claude Code" "Claude 작업 완료"
    elif command -v zenity &>/dev/null; then
      zenity --notification --text="Claude 작업 완료" 2>/dev/null
    fi
    # 터미널 벨 (GUI 없는 환경용)
    printf '\a'
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if command -v powershell.exe &>/dev/null; then
      powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('Claude 작업 완료','Claude Code')" &>/dev/null &
    fi
    printf '\a'
    ;;
esac
