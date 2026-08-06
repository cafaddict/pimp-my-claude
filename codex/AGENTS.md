# Personal Codex preferences

## Working agreements

- Prefer small, focused changes. Do not refactor unrelated code.
- Before declaring work complete, run the relevant tests, build, or static checks and report the result.
- Do not commit, push, or change remote state unless the user asks.
- For changes that span several files or have non-obvious dependencies, state a short plan before editing.
- Update the project documentation when a user-visible feature, API, or configuration changes.

## Writing

- Write expert-level C++ and Python, but explain decisions in clear, plain language.
- Use ordinary words in prose. Keep established technical terms such as `queue`, `TTFT`, and `backpressure` unchanged.

## Vault

- The optional shared knowledge vault uses `PIMP_MY_VAULT_DIR`; when it is unset, use `~/Documents/vault`.
- When a decision or lesson will be useful in a later project, use the installed `$vault-note` skill to save it.
- Use `$vault-recall` or `$vault-search` before repeating a decision that may already be recorded.

## Maintenance

- This file is installed by pimp-my-claude's Codex setup. Change the source repository, not only the installed copy.
