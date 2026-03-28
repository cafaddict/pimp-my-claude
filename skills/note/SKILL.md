---
name: note
description: |
  vault에 노트 자동 기록. 아래 상황에서 프로액티브하게 사용하라:
  - 아키텍처 결정을 내렸을 때 → decisions/
  - 새로운 패턴이나 접근법을 발견했을 때 → resources/
  - 프로젝트 관련 중요한 맥락이 생겼을 때 → projects/<프로젝트>/
  - 디버깅에서 의미있는 교훈을 얻었을 때 → lessons/
  - 실수나 삽질에서 배운 것이 있을 때 → lessons/
  - 지속적으로 지식을 쌓아가는 관심 영역 → areas/<영역명>/
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
| **lesson** | `lessons/` | 실수, 삽질, 디버깅에서 배운 교훈 |
| **resource** | `resources/` | 유용한 패턴, 스니펫, 참고 자료 |
| **project** | `projects/<name>/` | 프로젝트 관련 맥락 기록 |
| **area** | `areas/<영역명>/` | 지속적으로 지식을 쌓아가는 관심 영역 (리서치, 기술 스택, 도메인) |

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

## 관련
- [[프로젝트명]] ← 관련 프로젝트
- [[YYYY-MM-DD-HHMM]] ← 결정이 내려진 세션
```

**wikilink 규칙**: `## 관련`에 반드시 프로젝트, 세션 등 관련 노트를 `[[파일명]]`으로 연결. 실제 존재하는 파일만 링크.

파일명: `decisions/NNNN-<kebab-case-제목>.md` (NNNN은 기존 파일 수 + 1)

**lessons/**:
```markdown
---
date: YYYY-MM-DD
tags: [lesson, <관련태그>]
project: <프로젝트명 또는 빈칸>
---

# 교훈: <한 줄 요약>

## 상황
무엇을 하려 했는가

## 문제
무엇이 잘못되었는가 / 어떤 삽질을 했는가

## 교훈
다음에 어떻게 해야 하는가

## 관련
- [[YYYY-MM-DD-HHMM]] ← 이 교훈을 배운 세션
- [[프로젝트명]] ← 관련 프로젝트 (있으면)
```

**wikilink 규칙**: `## 관련`에 반드시 세션, 프로젝트 등 관련 노트를 `[[파일명]]`으로 연결. 실제 존재하는 파일만 링크.

파일명: `lessons/YYYY-MM-DD-<kebab-case-요약>.md`

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

**areas/<영역명>/**:

영역 폴더가 없으면 생성. 개별 노트를 누적하는 living doc — 계속 업데이트됨.

```markdown
---
date: YYYY-MM-DD
tags: [area, <영역태그>]
---

# <제목>

<내용>

## 관련
- [[관련노트]] ← 실제 존재하는 파일만 링크
```

**wikilink 규칙**: `## 관련`에 관련 노트를 `[[파일명]]`으로 연결. 실제 존재하는 파일만 링크.

파일명: `areas/<영역명>/<kebab-case-제목>.md`

**area vs resource 판별**: "이 주제에 대해 앞으로도 계속 지식을 쌓을 것인가?" → Yes면 area (폴더+누적), No면 resource (단일 파일, 작성 시점에 완결).

**projects/<name>/**:
프로젝트 폴더가 없으면 생성하고 CLAUDE.md 포함.

**프로젝트 노트와 지식 연결**: area나 resource 노트를 생성할 때, 관련 프로젝트가 있으면 해당 프로젝트 노트(`projects/<name>.md`)의 `## 지식` 섹션에 wikilink를 추가하라. 역으로, 프로젝트 노트 생성/업데이트 시 관련 area/resource가 있으면 `## 지식`에 연결.

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
