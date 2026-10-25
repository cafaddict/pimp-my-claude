#!/bin/bash
# statusLine: ~/.config/starship.toml 룩을 Claude Code 상태줄로 재현.
# 세그먼트 순서(스타십 format 기반 + Claude Code 전용 3개 추가): python(venv)
#   → os+user → directory → git branch/status → language → docker → time
#   → model → context usage → rate limits(5h/7d)
# 색상은 starship.toml의 hex(#9A348E/#DA627D/#FCA17D/#86BBD8/#06969A/#33658A)를
# 그대로 truecolor(24bit) ANSI로 변환하고, time 이후의 model/context/rate-limit
# 세그먼트는 같은 팔레트를 이어가는 인디고(#4C3B6E)·퍼플(#8E44AD)·마젠타(#94389E)로
# 확장해 원래 시작 색상(#9A348E, os+user)에 가깝게 되돌아오며 마무리된다. 화살표는
# Nerd Font powerline 글리프(). starship과 달리 빈 세그먼트(브랜치 없음/언어
# 미감지/도커 없음/컨텍스트 정보 없음/rate-limit 정보 없음)는 통째로 건너뛰고
# 인접한 두 블록 색으로 화살표를 이어붙인다 — 고정 프리셋 toml처럼 빈 칸이 뜨는 걸
# 방지.
#
# 성능 규칙(빠르게 끝나야 함, heavy/네트워크/빌드 명령 금지):
#   - git 조회는 --no-optional-locks 단일 `status --porcelain=2 --branch` 호출로 통일
#   - 언어/도구 버전은 조회하지 않음: rustup·Go toolchain·버전 관리자 shim은 작업 폴더의
#     설정 파일을 보고 toolchain을 내려받거나 다른 실행 파일을 고를 수 있다. 파일 존재로만 표시.
#   - docker CLI는 절대 호출하지 않음(데몬 미기동 시 행 걸릴 수 있어 파일 존재로만 판단)
#   - Nerd Font 글리프는 Private Use Area 문자라 복사·patch 과정에서 사라지기 쉬워
#     UTF-8 바이트 escape로 적는다(macOS 기본 bash 3.2는 $'\u....'를 지원하지 않음).

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

ESC=$'\033'
RESET="${ESC}[0m"
ARROW=$'\xee\x82\xb0'        # U+E0B0 powerline separator
ICON_OS=$'\xef\x85\xb9'      # U+F179 apple
ICON_BRANCH=$'\xee\x82\xa0'  # U+E0A0 git branch
ICON_RUST=$'\xee\x9e\xa8'    # U+E7A8
ICON_NODE=$'\xee\x9c\x98'    # U+E718
ICON_GO=$'\xee\x98\xa7'      # U+E627

fg() { printf '%s[38;2;%sm' "$ESC" "$1"; }
bg() { printf '%s[48;2;%sm' "$ESC" "$1"; }

# ---- python venv (starship: style "yellow", 배경 없음) ---------------------
PYTHON_SEG=""
if [ -n "$VIRTUAL_ENV" ]; then
  VENV_NAME=$(basename "$VIRTUAL_ENV")
  PYTHON_SEG="${ESC}[33m${VENV_NAME} 🐍 ${RESET}"
fi

# ---- os + username (bg #9A348E) --------------------------------------------
OS_USER_TEXT=" ${ICON_OS} $(whoami) "

# ---- directory (bg #DA627D) — truncation_length=3 + substitutions ---------
DISPLAY_DIR="$CWD"
case "$DISPLAY_DIR" in
  "$HOME"/*) DISPLAY_DIR="~${DISPLAY_DIR#"$HOME"}" ;;
  "$HOME") DISPLAY_DIR="~" ;;
esac
IS_ABS=0
case "$DISPLAY_DIR" in /*) IS_ABS=1 ;; esac

IFS='/' read -ra RAW_PARTS <<< "$DISPLAY_DIR"
COMPONENTS=()
for p in "${RAW_PARTS[@]}"; do
  [ -z "$p" ] && continue
  case "$p" in
    Documents) p=$'\xf3\xb0\x88\x99' ;;  # U+F0219
    Downloads) p=$'\xef\x80\x99' ;;  # U+F019
    Music) p=$'\xef\x80\x81' ;;      # U+F001
    Pictures) p=$'\xef\x80\xbe' ;;   # U+F03E
  esac
  COMPONENTS+=("$p")
done
N=${#COMPONENTS[@]}
if [ "$N" -gt 3 ]; then
  TRUNC="…/${COMPONENTS[$((N-3))]}/${COMPONENTS[$((N-2))]}/${COMPONENTS[$((N-1))]}"
else
  JOINED=$(IFS=/; echo "${COMPONENTS[*]}")
  if [ "$IS_ABS" -eq 1 ]; then TRUNC="/${JOINED}"; else TRUNC="$JOINED"; fi
fi
DIR_TEXT=" ${TRUNC} "

# ---- git branch + status (bg #FCA17D) --------------------------------------
GIT_TEXT=""
GIT_OUT=$(git --no-optional-locks -c core.fsmonitor=false -C "$CWD" status --porcelain=2 --branch 2>/dev/null)
if [ -n "$GIT_OUT" ]; then
  BRANCH=$(printf '%s\n' "$GIT_OUT" | awk '/^# branch\.head/ {print $3}')
  AB_LINE=$(printf '%s\n' "$GIT_OUT" | grep '^# branch\.ab')
  AHEAD=$(printf '%s\n' "$AB_LINE" | awk '{print $3}' | tr -d '+')
  BEHIND=$(printf '%s\n' "$AB_LINE" | awk '{print $4}' | tr -d '-')

  STAGED_N=$(printf '%s\n' "$GIT_OUT" | grep -cE '^[12] [^.]')
  MODIFIED_N=$(printf '%s\n' "$GIT_OUT" | grep -cE '^[12] .[^.]')
  CONFLICT_N=$(printf '%s\n' "$GIT_OUT" | grep -cE '^u ')
  UNTRACKED_N=$(printf '%s\n' "$GIT_OUT" | grep -cE '^\? ')

  STATUS_STR=""
  [ "${STAGED_N:-0}" -gt 0 ] && STATUS_STR+="+"
  [ "${MODIFIED_N:-0}" -gt 0 ] && STATUS_STR+="!"
  [ "${CONFLICT_N:-0}" -gt 0 ] && STATUS_STR+="="
  [ "${UNTRACKED_N:-0}" -gt 0 ] && STATUS_STR+="?"
  git --no-optional-locks -C "$CWD" rev-parse --verify --quiet refs/stash >/dev/null 2>&1 && STATUS_STR+='$'

  AB_STR=""
  [ -n "$AHEAD" ] && [ "$AHEAD" != "0" ] && AB_STR+="⇡${AHEAD}"
  [ -n "$BEHIND" ] && [ "$BEHIND" != "0" ] && AB_STR+="⇣${BEHIND}"

  GIT_TEXT=" ${ICON_BRANCH} ${BRANCH:-HEAD} "
  [ -n "${STATUS_STR}${AB_STR}" ] && GIT_TEXT+="${STATUS_STR}${AB_STR} "
fi

# ---- language (bg #86BBD8) — 감지된 첫 언어 하나만, 실행 파일은 호출하지 않음 ----
LANG_TEXT=""
if [ -f "$CWD/Cargo.toml" ]; then
  LANG_TEXT=" ${ICON_RUST} rust "
elif [ -f "$CWD/package.json" ]; then
  LANG_TEXT=" ${ICON_NODE} node "
elif [ -f "$CWD/go.mod" ]; then
  LANG_TEXT=" ${ICON_GO} go "
elif [ -f "$CWD/CMakeLists.txt" ]; then
  LANG_TEXT=" △ cmake "
fi

# ---- docker (bg #06969A) — docker CLI 호출 없이 파일 존재로만 판단 --------------
DOCKER_TEXT=""
if [ -f "$CWD/Dockerfile" ] || [ -f "$CWD/docker-compose.yml" ] || [ -f "$CWD/compose.yaml" ]; then
  DOCKER_TEXT=" 🐳 docker "
fi

# ---- time (bg #33658A) ------------------------------------------------------
TIME_TEXT=" ♥ $(date +%R) "

# ---- model (bg #4C3B6E) — Claude Code 세션의 현재 모델 -------------------------
MODEL_NAME=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // empty' 2>/dev/null)
MODEL_TEXT=""
# effort.level은 모델이 reasoning effort를 지원할 때만 존재 → 없으면 생략.
EFFORT_LEVEL=$(echo "$INPUT" | jq -r '.effort.level // empty' 2>/dev/null)
if [ -n "$MODEL_NAME" ]; then
  MODEL_TEXT=" 🤖 ${MODEL_NAME}"
  [ -n "$EFFORT_LEVEL" ] && MODEL_TEXT+=" · ${EFFORT_LEVEL}"
  MODEL_TEXT+=" "
fi

# ---- context usage (bg #8E44AD) — 컨텍스트 윈도우 사용률 ----------------------
# 우선 context_window.used_percentage(사전 계산된 값)를 쓰고, 옛 스키마 호환을
# 위해 context_percent도 폴백으로 확인한다. 메시지가 아직 없으면 null이라 세그먼트
# 자체를 생략(다른 조건부 세그먼트와 동일한 패턴).
CTX_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // .context_percent // empty' 2>/dev/null)
CTX_TEXT=""
if [ -n "$CTX_PCT" ]; then
  CTX_PCT_INT=$(printf '%.0f' "$CTX_PCT" 2>/dev/null)
  [ -n "$CTX_PCT_INT" ] && CTX_TEXT=" ◔ ${CTX_PCT_INT}% "
fi

# ---- rate limits (bg #94389E) — Claude.ai 구독 5시간/7일 사용률 ----------------
# 둘 다 없으면(구독 아님/첫 API 응답 전) 세그먼트 자체를 생략.
FIVE_HOUR_PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
SEVEN_DAY_PCT=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
RATE_TEXT=""
if [ -n "$FIVE_HOUR_PCT" ] || [ -n "$SEVEN_DAY_PCT" ]; then
  RATE_STR=""
  if [ -n "$FIVE_HOUR_PCT" ]; then
    FIVE_HOUR_INT=$(printf '%.0f' "$FIVE_HOUR_PCT" 2>/dev/null)
    [ -n "$FIVE_HOUR_INT" ] && RATE_STR+="5h ${FIVE_HOUR_INT}%"
  fi
  if [ -n "$SEVEN_DAY_PCT" ]; then
    SEVEN_DAY_INT=$(printf '%.0f' "$SEVEN_DAY_PCT" 2>/dev/null)
    if [ -n "$SEVEN_DAY_INT" ]; then
      [ -n "$RATE_STR" ] && RATE_STR+="  "
      RATE_STR+="7d ${SEVEN_DAY_INT}%"
    fi
  fi
  [ -n "$RATE_STR" ] && RATE_TEXT=" ⏳ ${RATE_STR} "
fi

# ---- 세그먼트 조립 -----------------------------------------------------------
COLORS=()
TEXTS=()
COLORS+=("154;52;142"); TEXTS+=("$OS_USER_TEXT")
COLORS+=("218;98;125"); TEXTS+=("$DIR_TEXT")
if [ -n "$GIT_TEXT" ]; then COLORS+=("252;161;125"); TEXTS+=("$GIT_TEXT"); fi
if [ -n "$LANG_TEXT" ]; then COLORS+=("134;187;216"); TEXTS+=("$LANG_TEXT"); fi
if [ -n "$DOCKER_TEXT" ]; then COLORS+=("6;150;154"); TEXTS+=("$DOCKER_TEXT"); fi
COLORS+=("51;101;138"); TEXTS+=("$TIME_TEXT")
if [ -n "$MODEL_TEXT" ]; then COLORS+=("76;59;110"); TEXTS+=("$MODEL_TEXT"); fi
if [ -n "$CTX_TEXT" ]; then COLORS+=("142;68;173"); TEXTS+=("$CTX_TEXT"); fi
if [ -n "$RATE_TEXT" ]; then COLORS+=("148;56;158"); TEXTS+=("$RATE_TEXT"); fi

OUT="$PYTHON_SEG"
PREV=""
for i in "${!COLORS[@]}"; do
  C="${COLORS[$i]}"
  T="${TEXTS[$i]}"
  if [ -n "$PREV" ]; then
    OUT+="$(fg "$PREV")$(bg "$C")${ARROW}${RESET}"
  else
    OUT+="$(fg "$C")${ARROW}${RESET}"
  fi
  OUT+="$(bg "$C")${T}${RESET}"
  PREV="$C"
done
OUT+="$(fg "$PREV")${ARROW}${RESET}"

printf '%s\n' "$OUT"
