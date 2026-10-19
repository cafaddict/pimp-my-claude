#!/bin/bash
# Claude Code 환경 부트스트랩
# 사용법: git clone <repo> && cd pimp-my-claude && ./setup.sh [옵션]
#
# 다시 실행해도 기존 설정이 우선이다. 직접 고친 설치본, 외부 hook handler, statusLine은
# 덮어쓰지 않는다. 설치된 hook 정의·스크립트를 바꾸는 일은 --upgrade-hooks 때만 한다.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
INSTALL_SDK=false
INSTALL_VAULT=false
INSTALL_MCP=false
FORCE_CLAUDE_MD=false
UPGRADE_HOOKS=false
DRY_RUN=false
VAULT_DIR="${PIMP_MY_VAULT_DIR:-${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}}"
# source에서 뺀 hook. 설치된 파일은 지우지 않고, --upgrade-hooks 때만 바인딩을 푼다.
RETIRED_HOOKS=(prompt-hint)

for arg in "$@"; do
  case "$arg" in
    --with-sdk)   INSTALL_SDK=true ;;
    --with-vault) INSTALL_VAULT=true ;;
    --with-mcp)   INSTALL_MCP=true ;;
    --all)        INSTALL_SDK=true; INSTALL_VAULT=true; INSTALL_MCP=true ;;
    --force-claude-md) FORCE_CLAUDE_MD=true ;;
    --upgrade-hooks) UPGRADE_HOOKS=true ;;
    --dry-run)    DRY_RUN=true ;;
    --help|-h)
      echo "사용법: ./setup.sh [옵션]"
      echo ""
      echo "옵션:"
      echo "  --with-sdk         Agent SDK 도구 설치 (Python 3.10+ 필요)"
      echo "  --with-vault       Obsidian vault 구조 생성"
      echo "  --with-mcp         MCP 시맨틱 검색 서버 설치 (fastembed + sqlite-vec)"
      echo "  --all              위 3개 전부 설치"
      echo "  --force-claude-md  CLAUDE.md 덮어쓰기 (기존 백업 후 교체)"
      echo "  --upgrade-hooks    설치된 hook 정의·스크립트를 현재 템플릿으로 갱신 (diff 출력, 백업 후 적용)"
      echo "                     이 작업만 하고 끝난다. 직접 고친 정의·파일은 보류하고 보고한다."
      echo "  --dry-run          --upgrade-hooks와 함께: 바뀔 내용만 보여 주고 아무것도 쓰지 않음"
      echo "  --help             이 도움말 표시"
      echo ""
      echo "환경변수:"
      echo "  PIMP_MY_VAULT_DIR vault 경로 (최우선, 기본: ~/Documents/vault)"
      echo "  CLAUDE_VAULT_DIR  Claude 호환 vault 경로"
      exit 0
      ;;
    *)
      echo "알 수 없는 옵션: $arg (./setup.sh --help 참고)" >&2
      exit 2
      ;;
  esac
done
if [ "$DRY_RUN" = true ] && [ "$UPGRADE_HOOKS" = false ]; then
  echo "--dry-run은 --upgrade-hooks와 함께 씁니다." >&2
  exit 2
fi

# shellcheck source=lib/install-lib.sh
source "$SCRIPT_DIR/lib/install-lib.sh"

SETTINGS="$CLAUDE_DIR/settings.json"
TEMPLATE="$SCRIPT_DIR/settings-template.json"
BACKUP_PARENT="$CLAUDE_DIR/pimp-my-claude-backups"
SCRIPT_DIR_REPL="$(pimp_sed_repl "$SCRIPT_DIR")"
HELD=()

is_retired() {
  local r
  for r in "${RETIRED_HOOKS[@]}"; do [ "$1" = "$r" ] && return 0; done
  return 1
}
render_repo_dir() { sed "s|{{REPO_DIR}}|$SCRIPT_DIR_REPL|g"; }
retired_json() {
  local r
  # shellcheck disable=SC2088  # literal "~/" as written in settings.json
  for r in "${RETIRED_HOOKS[@]}"; do printf '~/.claude/hooks/%s.sh\n' "$r"; done | jq -R . | jq -s .
}

# 아래 검사는 모두 파일을 쓰기 전에 한다. 하나라도 걸리면 아무것도 바꾸지 않고 멈춘다.
# skill 본문의 실행 줄에 레포 경로가 따옴표 없이 들어가므로, 그대로 실행할 수 없는 경로는 거부한다.
if [ "$UPGRADE_HOOKS" = false ] && ! pimp_shell_safe_path "$SCRIPT_DIR"; then
  echo "✗ 레포 경로에 공백이나 셸 특수문자가 있습니다: $SCRIPT_DIR" >&2
  echo "  skill의 실행 명령이 이 경로를 그대로 쓰므로 설치하지 않았습니다(아무것도 바꾸지 않음)." >&2
  echo "  공백·특수문자가 없는 경로로 clone한 뒤 다시 실행하세요." >&2
  exit 2
fi
# symlink(예: dotfiles)인 settings.json은 일반 파일로 바꿔 버리지 않도록 손대지 않는다.
if [ -L "$SETTINGS" ]; then
  echo "✗ $SETTINGS 는 symlink입니다($(readlink "$SETTINGS")). 연결을 끊지 않도록 아무것도 바꾸지 않았습니다." >&2
  echo "  병합하려면 symlink 대상 파일을 직접 편집하세요(템플릿: $TEMPLATE)." >&2
  exit 1
fi
# 기존 settings.json이 깨져 있거나 hooks 구조를 해석할 수 없으면 멈춘다.
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null && ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "✗ $SETTINGS 가 올바른 JSON이 아닙니다. 고친 뒤 다시 실행하세요. (아무것도 바꾸지 않았습니다)" >&2
  exit 1
fi
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null && ! pimp_hooks_readable "$SETTINGS" "$TEMPLATE"; then
  echo "✗ $SETTINGS 의 hooks 구조를 해석하지 못했습니다. 고친 뒤 다시 실행하세요. (아무것도 바꾸지 않았습니다)" >&2
  exit 1
fi

# --upgrade-hooks: 설치된 hook 바인딩·스크립트만 현재 템플릿으로 맞춘다.
upgrade_hooks() {
  local work known settings_changed=false f name dest replace=() held=() restore
  command -v jq &>/dev/null || { echo "✗ --upgrade-hooks에는 jq가 필요합니다." >&2; exit 1; }
  [ -f "$SETTINGS" ] || { echo "✗ $SETTINGS 가 없습니다. 먼저 ./setup.sh 를 실행하세요." >&2; exit 1; }
  work="$(mktemp -d "${TMPDIR:-/tmp}/pimp-upgrade.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  known="$(pimp_known_handlers settings-template.json)"
  if ! pimp_merge_hooks "$SETTINGS" "$TEMPLATE" upgrade "$known" "$(retired_json)" \
    "$work/settings.json" "$work/report.json"; then
    echo "✗ settings.json의 hooks 구조를 해석하지 못했습니다. 아무것도 바꾸지 않았습니다." >&2
    exit 1
  fi
  pimp_same_json "$SETTINGS" "$work/settings.json" || settings_changed=true

  for f in "$SCRIPT_DIR/hooks/"*.sh; do
    name="$(basename "$f" .sh)"
    is_retired "$name" && continue
    dest="$CLAUDE_DIR/hooks/$name.sh"
    case "$(pimp_classify "$f" "$dest" "hooks/$name.sh")" in
      missing|shipped) replace+=("$name") ;;
      modified) held+=("$name") ;;
    esac
  done

  echo "=== --upgrade-hooks: $SETTINGS ==="
  pimp_print_report "$work/report.json"
  if [ "$settings_changed" = true ]; then
    diff -u "$SETTINGS" "$work/settings.json" || true
  fi
  for name in "${replace[@]}"; do
    dest="$CLAUDE_DIR/hooks/$name.sh"
    echo "hook 파일 갱신: $dest"
    if [ -f "$dest" ]; then diff -u "$dest" "$SCRIPT_DIR/hooks/$name.sh" || true; else echo "  (새 파일)"; fi
  done
  for name in "${held[@]}"; do
    echo "⚠ 보류: $CLAUDE_DIR/hooks/$name.sh 는 직접 고친 파일이라 그대로 둡니다. 비교: diff -u '$CLAUDE_DIR/hooks/$name.sh' '$SCRIPT_DIR/hooks/$name.sh'"
  done
  jq -r '[.hooks // {} | to_entries[] | .key as $e | .value[]? | (.hooks // [])[]
          | select((.timeout // 0) > 600) | "\($e): \(.command // "?") timeout=\(.timeout)"] | .[]
          | "ℹ timeout 단위는 초입니다. 확인 권장(자동 수정 안 함): \(.)"' "$work/settings.json"

  if [ "$settings_changed" = false ] && [ "${#replace[@]}" -eq 0 ]; then
    echo "✓ 변경 없음"
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "(--dry-run) 아무것도 바꾸지 않았습니다."
    return 0
  fi

  BACKUP_DIR="$(pimp_new_backup_dir "$BACKUP_PARENT")"
  restore="$BACKUP_DIR/restore-commands.txt"
  echo "# pimp-my-claude --upgrade-hooks 되돌리기. 아래 명령을 그대로 실행한다." > "$restore"
  for name in "${replace[@]}"; do
    dest="$CLAUDE_DIR/hooks/$name.sh"
    if [ -f "$dest" ]; then
      mkdir -p "$BACKUP_DIR/hooks"
      cp -p "$dest" "$BACKUP_DIR/hooks/$name.sh"
      cmp -s "$dest" "$BACKUP_DIR/hooks/$name.sh"
      printf 'cp -p %q %q\n' "$BACKUP_DIR/hooks/$name.sh" "$dest" >> "$restore"
    else
      printf '# 새로 설치됨(필요 없으면 직접 삭제): %q\n' "$dest" >> "$restore"
    fi
  done
  if [ "$settings_changed" = true ]; then
    cp -p "$SETTINGS" "$BACKUP_DIR/settings.json"
    cmp -s "$SETTINGS" "$BACKUP_DIR/settings.json"
    printf 'cp -p %q %q\n' "$BACKUP_DIR/settings.json" "$SETTINGS" >> "$restore"
  fi

  mkdir -p "$CLAUDE_DIR/hooks"
  for name in "${replace[@]}"; do
    pimp_install_file "$SCRIPT_DIR/hooks/$name.sh" "$CLAUDE_DIR/hooks/$name.sh" 755
  done
  if [ "$settings_changed" = true ]; then
    pimp_install_file "$work/settings.json" "$SETTINGS" "$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS")"
  fi
  echo "✓ hook 갱신 완료. 백업: $BACKUP_DIR"
  echo "되돌리기 ($restore):"
  grep -v '^#' "$restore" | sed 's/^/  /'
  echo "설치된 스크립트 파일은 지우지 않았습니다. 새 Claude Code 세션부터 적용됩니다."
}

if [ "$UPGRADE_HOOKS" = true ]; then
  upgrade_hooks
  exit 0
fi

echo "=== Claude Code 환경 설정 ==="
echo ""

# 1. 필수 디렉토리 생성
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/bin"

# install_managed <new-file> <dest> <repo-path> <mode> <policy> [render...]
# policy "refresh": 예전 배포본이면 교체. policy "hold": 예전 배포본도 유지(--upgrade-hooks 몫).
# 직접 고친 파일은 어느 쪽이든 그대로 두고 HELD에 적는다.
PENDING=()
install_managed() {
  local new="$1" dest="$2" path="$3" mode="$4" policy="$5"
  shift 5
  case "$(pimp_classify "$new" "$dest" "$path" "$@")" in
    missing) pimp_install_file "$new" "$dest" "$mode" ;;
    current) ;;
    shipped)
      if [ "$policy" = refresh ]; then pimp_install_file "$new" "$dest" "$mode"
      else PENDING+=("$dest"); fi
      ;;
    modified) HELD+=("$dest") ;;
  esac
}

# 2. hooks 복사 — 이미 설치된 hook 스크립트는 --upgrade-hooks 때만 바꾼다
HOOK_COUNT=0
for f in "$SCRIPT_DIR/hooks/"*.sh; do
  name="$(basename "$f" .sh)"
  is_retired "$name" && continue
  HOOK_COUNT=$((HOOK_COUNT + 1))
  install_managed "$f" "$CLAUDE_DIR/hooks/$name.sh" "hooks/$name.sh" 755 hold
done
ACTIVE_COUNT="$(jq '[.hooks[][].hooks[]] | length' "$TEMPLATE" 2>/dev/null || echo "?")"
echo "✓ Hooks 설치 (${HOOK_COUNT}개, 기본 활성화 ${ACTIVE_COUNT}개)"
if [ "${#PENDING[@]}" -gt 0 ]; then
  echo "  ⚠ 새 버전이 있지만 기존 설치본을 유지한 hook ${#PENDING[@]}개 — 검토: ./setup.sh --upgrade-hooks --dry-run"
fi

# 2-1. bin 스크립트 복사 (statusline 등)
if [ -d "$SCRIPT_DIR/bin/" ] && ls "$SCRIPT_DIR/bin/"*.sh &>/dev/null; then
  for f in "$SCRIPT_DIR/bin/"*.sh; do
    install_managed "$f" "$CLAUDE_DIR/bin/$(basename "$f")" "bin/$(basename "$f")" 755 refresh
  done
  echo "✓ Bin 스크립트 설치 ($(ls "$SCRIPT_DIR/bin/"*.sh | wc -l | tr -d ' ')개)"
fi

# 3. skills 복사
RENDER_TMP="$(mktemp "${TMPDIR:-/tmp}/pimp-skill.XXXXXX")"
for d in "$SCRIPT_DIR/skills/"/*/; do
  skill_name=$(basename "$d")
  mkdir -p "$CLAUDE_DIR/skills/$skill_name"
  render_repo_dir < "$d"SKILL.md > "$RENDER_TMP"
  install_managed "$RENDER_TMP" "$CLAUDE_DIR/skills/$skill_name/SKILL.md" "skills/$skill_name/SKILL.md" 644 refresh render_repo_dir
done
rm -f "$RENDER_TMP"
echo "✓ Skills 설치 ($(ls -d "$SCRIPT_DIR/skills/"*/ | wc -l | tr -d ' ')개)"

# 3-1. agents 복사
if [ -d "$SCRIPT_DIR/agents/" ] && ls "$SCRIPT_DIR/agents/"*.md &>/dev/null; then
  for f in "$SCRIPT_DIR/agents/"*.md; do
    install_managed "$f" "$CLAUDE_DIR/agents/$(basename "$f")" "agents/$(basename "$f")" 644 refresh
  done
  echo "✓ Agents 설치 ($(ls "$SCRIPT_DIR/agents/"*.md | wc -l | tr -d ' ')개)"
fi

# 3-2. global rules 복사 (vault-notes, plain-words)
GLOBAL_RULES=""
for r in vault-notes plain-words; do
  if [ -f "$SCRIPT_DIR/rules-templates/$r.md" ]; then
    install_managed "$SCRIPT_DIR/rules-templates/$r.md" "$CLAUDE_DIR/rules/$r.md" "rules-templates/$r.md" 644 refresh
    GLOBAL_RULES="$GLOBAL_RULES $r"
  fi
done
if [ -n "$GLOBAL_RULES" ]; then
  echo "✓ Global rules 설치 ($(echo $GLOBAL_RULES | sed 's/^ //; s/ /, /g'))"
fi

if [ "${#HELD[@]}" -gt 0 ]; then
  echo "⚠ 직접 고친 것으로 보이는 설치본 ${#HELD[@]}개는 덮어쓰지 않았습니다:"
  for f in "${HELD[@]}"; do echo "    $f"; done
  echo "  source 버전으로 바꾸려면 그 파일을 따로 백업한 뒤 지우고 ./setup.sh 를 다시 실행하세요."
fi

# 4. settings.json 병합 — 기존 값이 우선. 같은 command가 이미 있으면 템플릿 handler를 더하지 않는다.
if [ -f "$SETTINGS" ]; then
  if command -v jq &>/dev/null; then
    MERGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pimp-merge.XXXXXX")"
    if ! pimp_merge_hooks "$SETTINGS" "$TEMPLATE" merge '[]' "$(retired_json)" \
      "$MERGE_DIR/settings.json" "$MERGE_DIR/report.json"; then
      rm -rf "$MERGE_DIR"
      echo "✗ settings.json의 hooks 구조를 해석하지 못해 병합하지 않았습니다(파일은 그대로). 고친 뒤 다시 실행하세요." >&2
      exit 1
    fi
    if pimp_same_json "$SETTINGS" "$MERGE_DIR/settings.json"; then
      echo "✓ settings.json 변경 없음 (기존 설정 우선)"
    else
      BACKUP_DIR="$(pimp_new_backup_dir "$BACKUP_PARENT")"
      cp -p "$SETTINGS" "$BACKUP_DIR/settings.json"
      pimp_install_file "$MERGE_DIR/settings.json" "$SETTINGS" "$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS")"
      echo "✓ settings.json 병합 (기존 값·hook·statusLine 우선, 백업: $BACKUP_DIR/settings.json)"
    fi
    pimp_print_report "$MERGE_DIR/report.json"
    if jq -e '.differs | length > 0' "$MERGE_DIR/report.json" >/dev/null; then
      echo "  → 템플릿과 다른 hook 정의는 그대로 두었습니다. 검토: ./setup.sh --upgrade-hooks --dry-run"
    fi
    rm -rf "$MERGE_DIR"
    if jq -e '[.hooks // {} | .[][]? | (.hooks // [])[] | .command // ""]
      | any(test("prompt-hint|vault-briefing|auto-format|pre-compact-save|subagent-stop-log"))' \
      "$SETTINGS" >/dev/null; then
      echo "⚠ 기존 선택형 context/automation hook은 보존되었습니다. 필요 없으면 settings.json에서 직접 제거하세요."
      echo "  pre-compact-save·subagent-stop-log 현재 버전은 vault 밖(~/.claude/pre-compact-backups, ~/.claude/pimp-logs)에 씁니다."
      echo "  설치된 스크립트가 예전 버전이면 ./setup.sh --upgrade-hooks 를 실행해야 바뀝니다(그 전에는 예전 위치에 씀)."
      echo "  기존 vault의 .gitignore에는 sessions/pre-compact/, sessions/subagent-activity.log 추가를 권장합니다(자동 수정 안 함)."
    fi
  else
    echo "⚠ jq 미설치 — settings.json 병합 건너뜀"
    echo "  수동: $SCRIPT_DIR/settings-template.json 참고"
  fi
else
  cp "$SCRIPT_DIR/settings-template.json" "$SETTINGS"
  echo "✓ settings.json 생성"
fi


# 5. CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ "$FORCE_CLAUDE_MD" = false ]; then
  echo "⚠ CLAUDE.md 이미 존재 — 템플릿: $SCRIPT_DIR/CLAUDE-template.md (--force-claude-md 로 덮어쓰기)"
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ "$FORCE_CLAUDE_MD" = true ]; then
  cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
  sed "s|{{REPO_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/CLAUDE-template.md" > "$CLAUDE_DIR/CLAUDE.md"
  echo "✓ CLAUDE.md 덮어쓰기 (백업: CLAUDE.md.bak)"
else
  sed "s|{{REPO_DIR}}|$SCRIPT_DIR|g" "$SCRIPT_DIR/CLAUDE-template.md" > "$CLAUDE_DIR/CLAUDE.md"
  echo "✓ CLAUDE.md 생성"
fi

# 5-1. AGENTS.md symlink (Linux Foundation AAIF 표준 호환 — Cursor/Codex/Windsurf)
AGENTS_DEST="$CLAUDE_DIR/AGENTS.md"
if [ -L "$AGENTS_DEST" ]; then
  : # 이미 symlink 존재 — 그대로 유지
elif [ -f "$AGENTS_DEST" ]; then
  echo "⚠ AGENTS.md 이미 파일로 존재 — symlink 생성 건너뜀"
else
  ln -s "CLAUDE.md" "$AGENTS_DEST"
  echo "✓ AGENTS.md → CLAUDE.md symlink (업계 표준 호환)"
fi

# 6. Vault 구조 생성 (옵션)
if [ "$INSTALL_VAULT" = true ]; then
  echo ""
  echo "--- Vault 구조 생성 ---"
  if [ -d "$VAULT_DIR" ] && [ "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]; then
    echo "⚠ $VAULT_DIR 이미 존재 — 구조 건너뜀, 템플릿/CLAUDE.md 업데이트"
    # 기존 vault: 템플릿만 업데이트 (기존 노트는 건드리지 않음)
    if [ -d "$VAULT_DIR/templates" ]; then
      cp "$SCRIPT_DIR/vault-template/templates/"*.md "$VAULT_DIR/templates/"
      echo "  ✓ Vault 템플릿 업데이트"
    fi
    if [ -f "$VAULT_DIR/CLAUDE.md" ]; then
      cp "$VAULT_DIR/CLAUDE.md" "$VAULT_DIR/CLAUDE.md.bak"
      cp "$SCRIPT_DIR/vault-template/CLAUDE.md" "$VAULT_DIR/CLAUDE.md"
      echo "  ✓ Vault CLAUDE.md 업데이트 (백업: CLAUDE.md.bak)"
    fi
  else
    mkdir -p "$VAULT_DIR"
    cp -r "$SCRIPT_DIR/vault-template/"* "$VAULT_DIR/"
    cp "$SCRIPT_DIR/vault-template/.gitignore" "$VAULT_DIR/"
    git -C "$VAULT_DIR" init --quiet
    git -C "$VAULT_DIR" add -A
    if ! git -C "$VAULT_DIR" commit -m "Initial vault structure" --quiet; then
      echo "✗ Vault 초기 commit 실패 — git user.name/user.email을 설정한 뒤 다시 실행하세요." >&2
      exit 1
    fi
    echo "✓ Vault 생성 및 초기 commit: $VAULT_DIR"
  fi

  # CLAUDE_VAULT_DIR을 쉘 rc에 등록 (기본값과 다를 때만)
  if [ "$VAULT_DIR" != "$HOME/Documents/vault" ] || ! grep -q "CLAUDE_VAULT_DIR" "${SHELL_RC:-$HOME/.zshrc}" 2>/dev/null; then
    SHELL_RC="$HOME/.$(basename "${SHELL:-zsh}")rc"
    if ! grep -q "CLAUDE_VAULT_DIR" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# Claude Code vault path" >> "$SHELL_RC"
      echo "export CLAUDE_VAULT_DIR=\"$VAULT_DIR\"" >> "$SHELL_RC"
      echo "✓ CLAUDE_VAULT_DIR=$VAULT_DIR → $SHELL_RC 에 추가"
    fi
  fi

  # vault 경로를 settings.json에 주입 (additionalDirectories + env)
  if command -v jq &>/dev/null && [ -f "$CLAUDE_DIR/settings.json" ]; then
    VAULT_TILDE="${VAULT_DIR/#$HOME/\~}"

    # permissions.additionalDirectories에 vault 경로 추가
    if ! jq -e ".permissions.additionalDirectories // [] | index(\"$VAULT_TILDE\")" "$CLAUDE_DIR/settings.json" &>/dev/null; then
      jq ".permissions.additionalDirectories = ((.permissions.additionalDirectories // []) + [\"$VAULT_TILDE\"])" \
        "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" \
        && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
      echo "✓ vault 경로 → settings.json additionalDirectories 추가"
    fi

    # env.CLAUDE_VAULT_DIR 주입 (Claude Code 세션에서 확실히 인식하도록)
    CURRENT_ENV_VAULT=$(jq -r '.env.CLAUDE_VAULT_DIR // empty' "$CLAUDE_DIR/settings.json")
    if [ "$CURRENT_ENV_VAULT" != "$VAULT_DIR" ]; then
      jq ".env.CLAUDE_VAULT_DIR = \"$VAULT_DIR\"" \
        "$CLAUDE_DIR/settings.json" > "$CLAUDE_DIR/settings.json.tmp" \
        && mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
      echo "✓ CLAUDE_VAULT_DIR → settings.json env 추가"
    fi
  fi
fi

# 7. MCP 시맨틱 검색 서버 (옵션)
if [ "$INSTALL_MCP" = true ]; then
  echo ""
  echo "--- MCP 시맨틱 검색 서버 설치 ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. MCP 설치를 건너뜁니다."
  else
    MCP_DIR="$SCRIPT_DIR/mcp"
    VENV_DIR="$MCP_DIR/.venv"

    if [ ! -d "$VENV_DIR" ]; then
      python3 -m venv "$VENV_DIR"
      echo "  Python venv 생성"
    fi

    "$VENV_DIR/bin/pip" install -q -r "$MCP_DIR/requirements.txt"
    echo "✓ Dependencies 설치 완료"

    # 임베딩 모델 사전 다운로드 (~220MB)
    "$VENV_DIR/bin/python" -c "from fastembed import TextEmbedding; TextEmbedding(model_name='sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')" 2>/dev/null
    echo "✓ Embedding 모델 다운로드 완료 (paraphrase-multilingual-MiniLM-L12-v2)"

    # Claude Code MCP 등록
    if command -v claude &>/dev/null; then
      claude mcp remove vault 2>/dev/null || true
      claude mcp add vault -s user \
        -e CLAUDE_VAULT_DIR="$VAULT_DIR" \
        -- "$VENV_DIR/bin/python" "$MCP_DIR/server.py"
      echo "✓ MCP 서버 등록: vault (user scope — 모든 프로젝트에서 사용 가능)"
    else
      echo "⚠ claude CLI 미설치 — MCP 수동 등록 필요:"
      echo "  claude mcp add vault -s user -e CLAUDE_VAULT_DIR=$VAULT_DIR -- $VENV_DIR/bin/python $MCP_DIR/server.py"
    fi

    echo "  (첫 검색 시 자동 인덱싱 ~15초)"
  fi
fi

# 8. Agent SDK 도구 (옵션)
if [ "$INSTALL_SDK" = true ]; then
  echo ""
  echo "--- Agent SDK 도구 설치 ---"

  if ! command -v python3 &>/dev/null; then
    echo "✗ python3 미설치. Agent SDK 설치를 건너뜁니다."
  else
    SDK_DIR="$SCRIPT_DIR/agent-tools"
    if [ ! -d "$SDK_DIR" ]; then
      echo "✗ agent-tools/ 디렉토리가 없습니다."
    else
      cd "$SDK_DIR"
      python3 -m venv .venv
      source .venv/bin/activate
      pip install -e ".[dev]" --quiet
      echo "✓ Agent SDK 도구 설치 완료"
      echo "  활성화: source $SDK_DIR/.venv/bin/activate"
      echo "  명령어: claude-review, claude-scan, claude-report"
      deactivate
    fi
  fi
fi

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "사용법:"
echo "  새 Claude Code 세션 시작 → 자동 적용"
echo "  /guide                  → 설치된 기능 확인"
echo "  ./init-project.sh       → 프로젝트별 rules/ 초기화"
if [ "$INSTALL_VAULT" = true ]; then
  echo "  /vault-recall [키워드]  → 이전 세션 컨텍스트 복원"
fi
if [ "$INSTALL_SDK" = true ]; then
  echo "  source agent-tools/.venv/bin/activate → SDK 도구 활성화"
fi
