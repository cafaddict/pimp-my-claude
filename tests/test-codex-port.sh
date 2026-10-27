#!/bin/bash
# Codex payload contracts; no real HOME, vault, CLI registration or network access.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/pimp-codex-port.XXXXXX")"
trap 'rm -rf "$PORT_TMP"' EXIT
export HOME="$PORT_TMP/home"
export CODEX_HOME="$PORT_TMP/codex"
export AGENTS_HOME="$PORT_TMP/agents"
export PIMP_MY_VAULT_DIR="$PORT_TMP/vault"
mkdir -p "$HOME/.claude" "$CODEX_HOME"
printf '%s\n' 'claude sentinel' > "$HOME/.claude/settings.json"
printf '%s\n' 'model = "keep-my-model"' > "$CODEX_HOME/config.toml"
printf '%s\n' '# My existing global guidance' > "$CODEX_HOME/AGENTS.md"
cp "$CODEX_HOME/config.toml" "$PORT_TMP/config.before"
cp "$CODEX_HOME/AGENTS.md" "$PORT_TMP/agents.before"

bash "$REPO_DIR/setup-codex.sh" > "$PORT_TMP/install.out"
cmp "$CODEX_HOME/config.toml" "$PORT_TMP/config.before"
cmp "$CODEX_HOME/AGENTS.md" "$PORT_TMP/agents.before"
test "$(cat "$HOME/.claude/settings.json")" = 'claude sentinel'
test ! -e "$PIMP_MY_VAULT_DIR"
test ! -e "$CODEX_HOME/hooks.json"

python3 - "$REPO_DIR" <<'PY'
import os
from pathlib import Path
import re
import sys
import tomllib

repo = Path(sys.argv[1])
skills = Path(os.environ['AGENTS_HOME']) / 'skills'
codex = Path(os.environ['CODEX_HOME'])
expected = {p.parent.name for p in (repo / 'skills').glob('*/SKILL.md')}
actual = {p.parent.name for p in skills.glob('*/SKILL.md')}
assert expected == actual, (expected - actual, actual - expected)
assert len(actual) == 23
roles = {p.stem for p in (repo / 'agents').glob('*.md')}
assert {p.stem for p in (codex / 'agents').glob('*.toml')} == roles
for path in (codex / 'agents').glob('*.toml'):
    role = tomllib.loads(path.read_text())
    assert role['name'] == path.stem
    assert role['description'] and role['developer_instructions']
    assert not {'model', 'model_reasoning_effort', 'sandbox_mode', 'approval_policy'} & role.keys()

explicit = {'guide', 'prompt', 'vault-daily', 'vault-add-project'}
for skill in actual:
    content = (skills / skill / 'SKILL.md').read_text()
    header = content.split('---', 2)[1]
    assert re.search(rf'^name: {re.escape(skill)}$', header, re.M)
    assert re.search(r'^description:', header, re.M)
    assert not re.search(r'^(allowed-tools|argument-hint|effort|disable-model-invocation):', header, re.M)
    assert not re.search(r'\{\{(CODEX_DIR|SKILLS_DIR|INSTALL_DIR|SOURCE_DIR|REPO_DIR)\}\}|\$ARGUMENTS|subagent_type:|isolation: worktree', content), skill
    if (repo / 'codex' / 'skills' / skill / 'SKILL.md').is_file():
        assert '.claude' not in content and 'CLAUDE_' not in content
        assert not re.search(r'(^|[\s`(])/(vault-[\w-]+|sdd|tdd|harness|taskloop)\b', content), skill
    if skill in explicit:
        policy = skills / skill / 'agents' / 'openai.yaml'
        assert 'allow_implicit_invocation: false' in policy.read_text()

templates = codex / 'pimp-my-codex' / 'rules-templates'
for source in (repo / 'rules-templates').glob('*.md'):
    assert (templates / source.name).read_bytes() == source.read_bytes()
checker = skills / 'plain-words' / 'scripts' / 'check.py'
assert checker.is_file() and os.access(checker, os.X_OK)
print('23 skills, 8 agents, invocation policies and resource paths verified')
PY

# Re-running preserves edits in every new payload category, including symlinks.
printf '\nMy task rule\n' >> "$AGENTS_HOME/skills/taskloop/SKILL.md"
printf '\n# My invocation policy\n' >> "$AGENTS_HOME/skills/guide/agents/openai.yaml"
printf '\n# My agent\n' >> "$CODEX_HOME/agents/implementer.toml"
printf '\nMy C++ rule\n' >> "$CODEX_HOME/pimp-my-codex/rules-templates/cpp.md"
mv "$CODEX_HOME/agents/researcher.toml" "$PORT_TMP/researcher.toml"
ln -s "$PORT_TMP/researcher.toml" "$CODEX_HOME/agents/researcher.toml"
snapshot() { find "$AGENTS_HOME" "$CODEX_HOME" -type f -exec cksum {} + | sort; }
snapshot > "$PORT_TMP/before.sum"
bash "$REPO_DIR/setup-codex.sh" > "$PORT_TMP/rerun.out"
snapshot > "$PORT_TMP/after.sum"
cmp "$PORT_TMP/before.sum" "$PORT_TMP/after.sum"
test -L "$CODEX_HOME/agents/researcher.toml"
rg -F 'Kept 4 skill file(s) or support file(s)' "$PORT_TMP/rerun.out" >/dev/null
bash "$REPO_DIR/setup-codex.sh" --upgrade-hooks > /dev/null
snapshot > "$PORT_TMP/after-hooks.sum"
# An explicit hooks upgrade may add hook files; payload edits must still be untouched.
while IFS= read -r line; do
  rg -F -x "$line" "$PORT_TMP/after-hooks.sum" >/dev/null
done < "$PORT_TMP/before.sum"
echo 'Codex port contracts passed'
