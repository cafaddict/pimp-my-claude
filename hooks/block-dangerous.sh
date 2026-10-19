#!/bin/bash
# PreToolUse hook: Bash 위험 명령 차단. 좁은 guardrail이며 native permissions를 대신하지 않는다.
#
# exit 0 = 허용
# exit 2 = 차단 (stderr → Claude에 피드백)
# exit 1 = 입력 JSON을 해석하지 못함(jq 없음·실패). 원시 입력에서 위험 명령을 찾지 못했을 때만
#          이 값을 쓴다. 0·2가 아닌 코드는 non-blocking error라 명령은 진행되지만, 조용히 통과하지는 않는다.
#
# 명령을 ; && || | ( ) ` 와 줄바꿈으로 나눈 뒤 각 조각의 첫 단어로 판정한다.
# 첫 단어는 `/bin/rm`, `\rm`처럼 써도 rm으로 본다. sudo/env/nice/timeout 같은 래퍼는 건너뛴다.
# 그래서 `echo "rm -rf /"`나 `rm -rf ./build`는 막지 않는다.

INPUT=$(cat)
PARSE_FAILED=false
if COMMAND=$(printf '%s' "$INPUT" | jq -er '.tool_input.command // ""' 2>/dev/null); then
  [ -z "$COMMAND" ] && exit 0
else
  # jq가 없거나 JSON이 아니면 원시 입력으로 같은 검사를 한다.
  PARSE_FAILED=true
  EXTRACTED=$(printf '%s' "$INPUT" \
    | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' \
    | sed -e 's/\\"/"/g')
  EXTRACTED="${EXTRACTED//\\n/$'\n'}"
  COMMAND="$EXTRACTED
$(printf '%s' "$INPUT" | tr '{}[],:"' '\n\n\n\n\n\n\n')"
fi

block() {
  echo "위험 명령 차단됨 ($1): $2" >&2
  exit 2
}

strip_quotes() { printf '%s' "$1" | tr -d "\"'"; }

# rm -rf 대상: 루트, 홈, 현재 디렉터리 자체만. ~/.claude/skills/foo, ./build 같은 경로는 허용.
is_root_target() {
  # shellcheck disable=SC2088  # literal ~ and $HOME as typed in the command
  case "$(strip_quotes "$1")" in
    /|/\*|'~'|'~/'|'~/*'|'$HOME'|'$HOME/'|'$HOME/*'|'${HOME}'|'${HOME}/'|'${HOME}/*'|.|./) return 0 ;;
  esac
  return 1
}

# 명령 이름 비교용: `\rm`의 백슬래시와 `/bin/rm`의 디렉터리를 뗀다.
cmd_name() { local w; w="$(strip_quotes "$1")"; w="${w#\\}"; printf '%s' "${w##*/}"; }

check_segment() {
  local seg="$1" words w i n sub short="" long="" target_hit=false wrapper=""
  read -r -a words <<< "$seg"
  n=${#words[@]}
  i=0
  # 앞의 래퍼(값을 받는 옵션 포함)와 환경변수 대입은 건너뛴다.
  while [ "$i" -lt "$n" ]; do
    w="$(strip_quotes "${words[$i]}")"
    if [[ "$w" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi
    case "$(cmd_name "$w")" in
      sudo|command|exec|nohup|time|env|xargs|eval|nice|timeout|'{'|'!'|then|do|else)
        wrapper="$(cmd_name "$w")"; i=$((i + 1)) ;;
      bash|sh|zsh|dash)
        if [ "$((i + 1))" -lt "$n" ] && [[ "${words[$((i + 1))]}" =~ ^-[a-z]*c$ ]]; then
          i=$((i + 2))
        else
          return 0
        fi
        ;;
      -*)
        [ "$i" -gt 0 ] || return 0
        case "$wrapper:$w" in
          sudo:-[ughpCUrtD]|nice:-n|timeout:-[sk]|env:-[uSC]|xargs:-[IinLPsdEa]) i=$((i + 2)) ;;
          *) i=$((i + 1)) ;;
        esac
        ;;
      [0-9]*)  # timeout의 시간 인자
        if [ "$wrapper" = timeout ]; then wrapper=""; i=$((i + 1)); else break; fi
        ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 0
  w="$(cmd_name "${words[$i]}")"
  case "$w" in
    rm)
      for ((i = i + 1; i < n; i++)); do
        w="$(strip_quotes "${words[$i]}")"
        case "$w" in
          --) ;;
          --*) long="$long $w" ;;
          -*) short="$short${w#-}" ;;
          *) is_root_target "$w" && target_hit=true ;;
        esac
      done
      if [ "$target_hit" = true ] \
        && { [[ "$short" == *[rR]* ]] || [[ "$long" == *" --recursive"* ]]; } \
        && { [[ "$short" == *f* ]] || [[ "$long" == *" --force"* ]]; }; then
        block "시스템 경로 삭제" "$seg"
      fi
      ;;
    git)
      # 전역 옵션(-C <dir>, -c <k=v>, --git-dir=...)을 지나 subcommand를 찾는다.
      for ((i = i + 1; i < n; i++)); do
        w="$(strip_quotes "${words[$i]}")"
        case "$w" in
          -C|-c) i=$((i + 1)) ;;
          -*) ;;
          *) sub="${w#\\}"; break ;;
        esac
      done
      for ((i = i + 1; i < n; i++)); do
        w="$(strip_quotes "${words[$i]}")"
        case "$w" in
          --) break ;;
          --*) long="$long $w" ;;
          -*) short="$short${w#-}" ;;
        esac
      done
      case "$sub" in
        push)
          if [[ "$short" == *f* ]] || [[ "$long" == *" --force"* ]]; then
            block "git push --force" "$seg"
          fi
          ;;
        reset)
          [[ "$long" == *" --hard"* ]] && block "git reset --hard" "$seg"
          ;;
        clean)
          if { [[ "$short" == *f* ]] || [[ "$long" == *" --force"* ]]; } && [[ "$short" == *d* ]]; then
            block "git clean -fd" "$seg"
          fi
          ;;
      esac
      ;;
  esac
  return 0
}

while IFS= read -r segment; do
  check_segment "$segment"
done < <(printf '%s\n' "$COMMAND" | tr ';&|()`' '\n\n\n\n\n\n')

# SQL 위험 명령은 따옴표 안(psql -c "...")에 있어도 막는다.
if printf '%s\n' "$COMMAND" | grep -qiE 'DROP[[:space:]]+(TABLE|DATABASE)'; then
  block "SQL" "$(printf '%s' "$COMMAND" | head -1)"
fi

if [ "$PARSE_FAILED" = true ]; then
  echo "block-dangerous: hook 입력을 JSON으로 해석하지 못했습니다(jq 확인). 원시 입력에서는 위험 명령을 찾지 못해 진행합니다." >&2
  exit 1
fi
exit 0
