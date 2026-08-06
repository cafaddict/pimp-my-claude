#!/bin/bash
# 프로젝트 초기화: .claude/rules/ + vault 프로젝트 폴더
# 사용법: ./init-project.sh [언어...]
# 예시:   init-project.sh cpp python
#         init-project.sh python
#         init-project.sh              (기본: cpp python)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
PROJECT_NAME=$(basename "$PROJECT_DIR")
VAULT_DIR="${PIMP_MY_VAULT_DIR:-${CLAUDE_VAULT_DIR:-$HOME/Documents/vault}}"

echo "=== 프로젝트 초기화: $PROJECT_NAME ==="
echo ""

# 1. .claude/rules/ 설정
mkdir -p "$PROJECT_DIR/.claude/rules"

LANGS=("${@:-cpp python}")
for lang in "${LANGS[@]}"; do
  if [ -f "$SCRIPT_DIR/rules-templates/$lang.md" ]; then
    cp "$SCRIPT_DIR/rules-templates/$lang.md" "$PROJECT_DIR/.claude/rules/"
    echo "✓ rules/$lang.md 설치"
  else
    echo "⚠ $lang.md 템플릿 없음. 사용 가능: $(ls "$SCRIPT_DIR/rules-templates/" | sed 's/\.md//g' | tr '\n' ' ')"
  fi
done

if [ -f "$SCRIPT_DIR/rules-templates/testing.md" ]; then
  cp "$SCRIPT_DIR/rules-templates/testing.md" "$PROJECT_DIR/.claude/rules/"
  echo "✓ rules/testing.md 설치"
fi

# 2. vault에 프로젝트 노트 생성
if [ -d "$VAULT_DIR" ]; then
  VAULT_PROJECT="$VAULT_DIR/projects/$PROJECT_NAME.md"
  if [ -f "$VAULT_PROJECT" ]; then
    echo "✓ vault 프로젝트 이미 존재: $VAULT_PROJECT"
  else
    mkdir -p "$VAULT_DIR/projects"

    # 프로젝트 노트 생성
    REPO_URL=$(cd "$PROJECT_DIR" && git remote get-url origin 2>/dev/null || echo "")
    cat > "$VAULT_PROJECT" << EOF
---
date: $(date +%Y-%m-%d)
tags: [project]
status: active
repo: $REPO_URL
---

# 프로젝트: $PROJECT_NAME

## 개요


## 기술 스택


## 관련 결정
-

## 관련 세션
-

EOF

    "$SCRIPT_DIR/bin/vault-sync.sh" --commit "project: init $PROJECT_NAME" -- "projects/$PROJECT_NAME.md"
    echo "✓ vault 프로젝트 생성·동기화: projects/$PROJECT_NAME.md"
  fi
else
  echo "⚠ vault 없음 ($VAULT_DIR) — vault 프로젝트 생성 건너뜀"
fi

echo ""
echo "=== 초기화 완료 ==="
echo "  .claude/rules/: $(ls "$PROJECT_DIR/.claude/rules/" | tr '\n' ' ')"
[ -f "$VAULT_PROJECT" ] && echo "  vault: projects/$PROJECT_NAME.md"
