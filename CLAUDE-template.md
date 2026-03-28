# Personal Preferences

## Expertise
- I am an expert in C++ and Python. Write expert-level code — no dumbed-down solutions.
- Assume familiarity with advanced concepts: templates, metaprogramming, RAII, move semantics, smart pointers, Python decorators, generators, asyncio, type hints.
- **However, always explain code so that a college sophomore could understand it.** Use plain language, break down complex logic step by step, and clarify *why* each design choice was made — even if the code itself is advanced.

## C++
- Prefer modern C++ (C++17/20/23) idioms and features
- Use `std::` containers and algorithms over raw loops where clearer
- Prefer `auto` for complex types, explicit types for clarity at interfaces
- Use RAII and smart pointers (`std::unique_ptr`, `std::shared_ptr`) — no raw `new`/`delete`
- Prefer `constexpr` and `const` wherever possible
- Use `std::optional`, `std::variant`, `std::expected` over error codes or exceptions where appropriate
- Follow the Rule of Five/Zero
- Prefer `std::string_view` and `std::span` for non-owning references
- Use namespaces to organize code; avoid `using namespace std`

## Python
- Target Python 3.10+ unless the project specifies otherwise
- Use type hints for all function signatures
- Prefer f-strings over `.format()` or `%`
- Use `pathlib.Path` over `os.path`
- Prefer list/dict comprehensions when readable; break into loops when complex
- Use `dataclasses` or `pydantic` for structured data — avoid raw dicts for known schemas
- Use `pytest` for testing, not `unittest`
- Prefer `logging` over `print` for anything beyond quick debugging

## Code Style (General)
- Write clear, self-documenting code; use comments only when the "why" isn't obvious
- Keep functions short and focused on a single responsibility
- Prefer composition over inheritance
- Naming: descriptive over terse (`calculate_total` not `calc`)

## Prompt Structure
내가 비구조적 프롬프트를 주면, 내부적으로 이 구조를 적용하라:
- Task: 무엇을 해야 하는지
- Context: 왜 필요한지, 배경
- Requirements: 구체적 조건 (가정하지 말고 물어봐라)
- Output: 코드? 설명? JSON?

한 턴에 여러 모드를 섞지 마라:
- Build: 코드 작성에만 집중
- Learn: 개념 이해/설명
- Critique: 코드 검토 → /review 사용
- Debug: 에러 분석 → /debugit 사용

## Workflow
- 3개 이상 파일 수정 → Plan Mode 먼저
- 복잡한 다단계 작업 → /taskloop 사용
- 새 작업은 새 세션에서 — 컨텍스트 오염 방지
- 컨텍스트 위생: 70%에서 정밀도 저하, 85%에서 환각 증가 → 70% 전에 /compact 선제 실행
- 무거운 탐색은 서브에이전트(Explore)에 위임하여 메인 컨텍스트 보존
- 병렬 작업이 필요하면 git worktrees 사용 (`claude --worktree <name>`)
- 테스트/컴파일로 변경 검증 후 완료 선언
- 자동 커밋 금지. 최소 변경 원칙.
- 실수 발생 시 이 파일에 즉시 교훈 추가 (living document)

## Vault (Second Brain)
작업 중 중요한 결정, 발견, 교훈이 있으면 **자동으로 vault에 기록하라** (note 스킬 사용).
사용자가 요청하지 않아도 프로액티브하게 기록. vault 경로: ~/Documents/vault/
- 실수/삽질에서 배운 것 → vault의 lessons/에 기록 (note 스킬)
- 새 세션 시작 시 vault의 lessons/를 참고하여 같은 실수 반복 방지

## Custom Skills
- `/debugit` — 체계적 디버깅 (가설 수립 → 검증 → 수정 → 테스트)
- `/review [PR번호]` — 코드 리뷰 (정확성/보안/성능/테스트 4관점)
- `/perf` — 성능 분석 (프로파일링 → 병목 → 최적화 → 벤치마크)
- `/prompt` — 프롬프트를 Task/Context/Req/Output 구조로 변환
- `/taskloop [태스크명]` — Boris 스타일 태스크 루프 (.claude/tasks/ 기반)
- `/recall [키워드]` — 이전 세션 컨텍스트 복원 (vault 시맨틱 검색)
- `/daily` — 하루 마무리 정리 (오늘 세션 종합 → daily note)
- `/guide` — 설치된 기능 전체 가이드

## Tips
- `&` 접두사: 원격 샌드박스에서 무거운 분석 오프로드
- `/doctor`: 환경 문제 자동 진단
- `/context`: 현재 컨텍스트 사용량 확인
- `Ctrl+G`: 외부 에디터에서 긴 프롬프트 작성

## Tools
- Use `cmake` for C++ build systems
- Use `pytest` with clear test names (`test_<thing>_<condition>_<expected>`)
- Prefer `pip` + `venv` for Python environments unless the project uses something else

## Plugins
The following Claude Code plugins are installed and enabled. Use them proactively where appropriate — don't wait to be asked.

- **Context7 MCP** — Always use for library/API documentation, code examples, and setup/configuration steps. Prefer this over guessing or using stale knowledge.
- **GitHub MCP** — Use for GitHub operations (issues, PRs, repo info) when `gh` CLI isn't sufficient or when richer context is needed.
- **clangd LSP** — Use for C++ diagnostics, completions, and go-to-definition. Leverage this when working on C++ codebases for accurate type info and error checking.
- **Code Review** (`/code-review`) — Use when asked to review a PR or when reviewing code changes.
- **Code Simplifier** — Use when asked to simplify, clean up, or refactor code for clarity.
- **Commit Commands** (`/commit`, `/commit-push-pr`, `/clean_gone`) — Use for git workflows. Never auto-commit unless explicitly asked.
- 주의: MCP 서버는 사용 안 해도 컨텍스트 8~30% 소비. 안 쓰는 서버는 비활성화.
