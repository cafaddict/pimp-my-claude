# Repository guidance

This repository ships optional Claude Code and Codex CLI workflows. Keep their behavior explicit, low-noise, and safe for personal repositories.

## Verify changes

- Shell installers/hooks: `bash -n setup.sh setup-codex.sh hooks/*.sh`
- Python MCP changes: `python3 -m py_compile mcp/*.py`
- JSON config changes: `jq empty settings-template.json codex/hooks.json`
- Run `git diff --check` before handoff.

## Boundaries

- Do not add per-turn context injection or automatic memory capture by default. The installed `plain-words-remind` hook is the explicit exception: keep it enabled to reinforce the writing style on every prompt.
- Vault notes may be created only when the user asks or accepts a proposal. Once a vault operation begins, use `bin/vault-sync.sh` to keep its configured remote synchronized automatically; stop and report conflicts rather than discarding work.
- Treat hooks as narrow guardrails, not complete security controls. Keep automatic file mutation out of the default configuration.
- Use parallel agents only for independent, bounded work. Do not give multiple agents overlapping write scopes.

## Platform support

- Claude-specific assets live in `skills/`, `agents/`, `hooks/`, and `settings-template.json`.
- Codex support must use its documented `AGENTS.md`, `.agents/skills`, `.codex` config, hooks, and MCP formats. Do not claim Claude Agent Teams or Claude agent markdown is Codex-compatible.
