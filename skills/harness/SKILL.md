---
name: harness
description: |
  Claude Code harness 컴포넌트 개발. hook/skill/agent/설정 생성 및 테스트.
  소스 레포(~/Documents/claude-code-config/)에서 개발 → ~/.claude/에 배포.
  Use when: "harness", "hook 만들어", "skill 추가", "agent 추가" 요청 시.
argument-hint: "[컴포넌트 설명]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
effort: high
---

## Harness Engineering (Build Loop 포함)

Claude Code harness 컴포넌트를 체계적으로 개발한다.
소스 레포(~/Documents/claude-code-config/)가 진실의 원천 — 여기서 개발하고 ~/.claude/에 배포.

---

### Phase 1: CLASSIFY

$ARGUMENTS를 파싱하여 컴포넌트 타입을 판별:

| 타입 | 파일 위치 | 설명 |
|------|----------|------|
| **hook** | `hooks/<name>.sh` | PreToolUse/PostToolUse/Stop 이벤트 핸들러 |
| **skill** | `skills/<name>/SKILL.md` | 슬래시 커맨드로 호출하는 워크플로우 |
| **agent** | `agents/<name>.md` | 서브에이전트/팀원 정의 |
| **setting** | `settings-template.json` | 환경변수, 플러그인, 훅 등록 |

복합 컴포넌트 (예: 새 skill + 그에 필요한 agent)는 의존성 순서를 명시.

---

### Phase 2: SPEC

`spec-writer` 에이전트를 호출 (harness 맥락 주입):

```
요구사항: $ARGUMENTS
컴포넌트 타입: <Phase 1 결과>
소스 레포: ~/Documents/claude-code-config/

harness 컴포넌트 스펙을 작성하라.
기존 컴포넌트의 패턴(frontmatter, 파일 구조)을 따르라.
참고: hooks/ skills/ agents/ 디렉토리의 기존 파일들을 읽어 패턴을 파악하라.
```

컴포넌트별 스펙 포함 사항:
- **Hook**: 매칭 이벤트, 입력 JSON 형식, exit code 의미, 차단 조건
- **Skill**: frontmatter 필드, 워크플로우 단계, 사용 에이전트, 허용 도구
- **Agent**: frontmatter 필드, 역할 설명, 도구 접근, 출력 형식
- **Setting**: 변경할 JSON 키, 영향받는 훅/플러그인

---

### Phase 3: REVIEW

스펙을 사용자에게 제시하고 승인 요청.
기존 컴포넌트와 이름 충돌이 있으면 경고.

---

### Phase 4: BUILD LOOP

`/sdd`와 유사한 implement ↔ verify 루프 (harness-tester가 evaluator 역할).

#### 4a: IMPLEMENT

소스 레포(`~/Documents/claude-code-config/`)에 파일을 작성.

컴포넌트별 작성 규칙:
- **Hook**: `hooks/<name>.sh`, `chmod +x`, shebang 포함, stdin JSON 처리, exit code 사용
- **Skill**: `skills/<name>/SKILL.md`, YAML frontmatter + 마크다운 body
- **Agent**: `agents/<name>.md`, YAML frontmatter + 역할/출력/규칙 섹션
- **Setting**: `settings-template.json`에 병합 (`jq` 사용)

#### 4b: TEST

`harness-tester` 에이전트를 호출:

```
컴포넌트 타입: <타입>
파일 경로: <작성된 파일>
소스 레포: ~/Documents/claude-code-config/

이 harness 컴포넌트를 검증하라.
```

#### 4c: DECISION

- **PASS** → Phase 5
- **FAIL** → 피드백으로 4a 재실행 (max 3회)

---

### Phase 5: DEPLOY

소스 레포에서 ~/.claude/로 배포:

```bash
# Hook
cp ~/Documents/claude-code-config/hooks/<name>.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/<name>.sh

# Skill
mkdir -p ~/.claude/skills/<name>
cp ~/Documents/claude-code-config/skills/<name>/SKILL.md ~/.claude/skills/<name>/

# Agent
cp ~/Documents/claude-code-config/agents/<name>.md ~/.claude/agents/

# Setting — 병합 (덮어쓰기 아닌 머지)
# 사용자에게 diff 보여주고 승인 후 적용
```

배포 후 source ↔ deployed 동기화 확인:
```bash
diff <source-file> <deployed-file>
```

---

### Phase 6: SYNC

1. **README.md 업데이트**: 새 컴포넌트를 해당 섹션 테이블에 추가, 카운트 업데이트
2. **CLAUDE-template.md 업데이트**: skill/agent 추가 시 Custom Skills 목록에 반영
3. 사용자에게 git commit 제안

---

### 주의

- 항상 소스 레포 먼저, 배포 나중
- settings.json 직접 덮어쓰기 금지 — diff 확인 후 병합
- hook에서 `claude -p` 호출 금지 (무한루프 위험 — lessons 참고)
- `/debug`처럼 내장 명령어와 이름 충돌 확인 필수
- 기존 컴포넌트 수정 시에도 이 워크플로우 사용 가능 (CLASSIFY에서 "수정"으로 판별)
