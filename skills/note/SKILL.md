---
name: note
description: |
  vault에 노트 자동 기록. 아래 상황에서 프로액티브하게 사용하라:
  - 아키텍처 결정을 내렸을 때 → decisions/
  - 새로운 패턴이나 접근법을 발견했을 때 → resources/
  - 프로젝트 관련 중요한 맥락이 생겼을 때 → projects/<프로젝트>/
  - 디버깅에서 의미있는 교훈을 얻었을 때 → resources/
  사용자가 직접 호출하지 않아도 자동으로 사용하라.
allowed-tools: Read, Write, Bash, Glob
---

## Vault 노트 자동 기록

VAULT_DIR은 `~/Documents/vault` (환경변수 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

### 노트 타입 판별

기록할 내용의 성격에 따라 자동으로 타입을 판별하라:

| 타입 | 디렉토리 | 언제 |
|------|----------|------|
| **decision** | `decisions/` | 아키텍처/기술 선택을 결정했을 때 |
| **resource** | `resources/` | 유용한 패턴, 스니펫, 교훈을 발견했을 때 |
| **project** | `projects/<name>/` | 프로젝트 관련 맥락 기록 |

### 파일 생성 규칙

**decisions/**:
```markdown
---
date: YYYY-MM-DD
tags: [decision, adr]
project: <프로젝트명 또는 빈칸>
status: accepted
---

# ADR: <제목>

## 맥락
<왜 이 결정이 필요했는가>

## 결정
<무엇을 결정했는가>

## 근거
<왜 이 결정을 했는가, 대안은 무엇이었는가>

## 결과
<예상 영향>
```

파일명: `decisions/NNNN-<kebab-case-제목>.md` (NNNN은 기존 파일 수 + 1)

**resources/**:
```markdown
---
date: YYYY-MM-DD
tags: [resource, <관련태그>]
---

# <제목>

<내용>
```

파일명: `resources/<kebab-case-제목>.md`

**projects/<name>/**:
프로젝트 폴더가 없으면 생성하고 CLAUDE.md 포함.

### git sync

노트 작성 후 반드시 실행:
```bash
cd $VAULT_DIR && git add -A && git commit -m "note: <타입> - <제목>" --quiet && git push --quiet &
```

실패해도 무시 (best-effort).

### 주의
- 사소한 내용은 기록하지 마라. **나중에 다시 찾을 가치가 있는 것만** 기록.
- 이미 비슷한 노트가 있으면 업데이트하라 (중복 생성 금지).
- 기록 시 사용자에게 한 줄로 알려라: "📝 vault에 기록: decisions/0001-jwt-strategy.md"
