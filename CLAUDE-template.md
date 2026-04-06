# Personal Preferences

## Expertise
- I am an expert in C++ and Python. Write expert-level code — no dumbed-down solutions.
- Assume familiarity with advanced concepts: templates, metaprogramming, RAII, move semantics, smart pointers, Python decorators, generators, asyncio, type hints.
- **However, always explain code so that a college sophomore could understand it.** Use plain language, break down complex logic step by step, and clarify *why* each design choice was made — even if the code itself is advanced.

- C++/Python 코딩 스타일: 프로젝트 .claude/rules/ 또는 개인 스타일 가이드 참고

## Code Style (General)
- 자기 문서화 코드, 단일 책임 함수, 구성 > 상속, 서술적 이름

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
- git commit 전에 변경 내용이 프로젝트 README에 반영되어야 하는지 확인하고, 필요하면 업데이트. 단순 버그 수정은 불필요, API/기능/설정 변경은 필요.
- 실수 발생 시 이 파일에 즉시 교훈 추가 (living document)
- ~/.claude/ 의 hook/skill을 수정할 때는 {{REPO_DIR}}/ 레포에도 반영 + README.md 업데이트

## Vault (Second Brain)
작업 중 중요한 결정, 발견, 교훈이 있으면 **자동으로 vault에 기록하라** (note 스킬 사용).
사용자가 요청하지 않아도 프로액티브하게 기록. vault 경로: ~/Documents/vault/
- **결정을 내렸으면 반드시 /note로 decisions/에 기록하라** — 기술 선택, 아키텍처 결정, 설계 방향 등
- 실수/삽질에서 배운 것 → vault의 lessons/에 기록 (note 스킬)
- 새 세션 시작 시 vault의 lessons/와 decisions/를 참고하여 같은 실수/재논의 방지

- Custom Skills: ~/.claude/skills/ 에 설치됨. /guide로 확인.

## Tips
- `&` 접두사: 원격 샌드박스에서 무거운 분석 오프로드
- `/doctor`: 환경 문제 자동 진단
- `/context`: 현재 컨텍스트 사용량 확인
- `Ctrl+G`: 외부 에디터에서 긴 프롬프트 작성

## Plugins
Context7(라이브러리 문서), GitHub, clangd(C++), Code Review, Code Simplifier, Commit Commands 활성화.
주의: MCP 서버는 사용 안 해도 컨텍스트 8~30% 소비. 안 쓰는 서버는 비활성화.
