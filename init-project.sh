#!/bin/bash
# 현재 프로젝트에 .claude/rules/ 설정
# 사용법: ~/Documents/claude-code-config/init-project.sh [언어...]
# 예시:   init-project.sh cpp python
#         init-project.sh python       (Python만)
#         init-project.sh              (기본: cpp python)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"

echo "=== 프로젝트 초기화: $PROJECT_DIR ==="

mkdir -p "$PROJECT_DIR/.claude/rules"

LANGS=("${@:-cpp python}")
for lang in "${LANGS[@]}"; do
  if [ -f "$SCRIPT_DIR/rules-templates/$lang.md" ]; then
    cp "$SCRIPT_DIR/rules-templates/$lang.md" "$PROJECT_DIR/.claude/rules/"
    echo "✓ $lang.md 규칙 설치"
  else
    echo "⚠ $lang.md 템플릿이 없습니다. 사용 가능: $(ls "$SCRIPT_DIR/rules-templates/" | sed 's/\.md//g' | tr '\n' ' ')"
  fi
done

# testing rules는 항상 포함
if [ -f "$SCRIPT_DIR/rules-templates/testing.md" ]; then
  cp "$SCRIPT_DIR/rules-templates/testing.md" "$PROJECT_DIR/.claude/rules/"
  echo "✓ testing.md 규칙 설치"
fi

echo ""
echo "=== .claude/rules/ 초기화 완료 ==="
echo "설치된 규칙:"
ls "$PROJECT_DIR/.claude/rules/"
