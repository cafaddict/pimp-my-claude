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
effort: medium
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
| **area** | `areas/<영역명>/` | 지속적으로 지식을 쌓아가는 관심 영역 |

### 공통 wikilink 규칙

1. `## 관련` 섹션에 관련 노트를 `[[파일명]]`으로 연결. Obsidian shortest-name resolution 사용.
2. **링크 전 검증**: Glob으로 vault 내 파일 존재 확인. 존재하지 않는 파일은 링크하지 마라.
3. **양방향 링크**: 노트 생성 시 관련 프로젝트 노트의 해당 섹션에도 역링크 추가.
4. **고아 노트 금지**: 모든 노트는 `## 관련`에 최소 1개 wikilink를 가져야 한다.

### 파일 생성 규칙

**decisions/**:
- frontmatter: `date`, `tags:[decision,adr,<관련태그>]`, `project`, `status:accepted`, `summary:<1문장 요약>`
- 구조:
  ```
  # ADR: <제목>
  ## 맥락
  ## 검토한 대안
  (최소 2개 대안을 표로 비교: | 기준 | 옵션A | 옵션B | 선택 |)
  ## 결정
  ## 근거
  ## 트레이드오프
  (이 결정의 장점, 단점, 리스크)
  > [!warning] 주의사항
  > (적용 시 주의할 점)
  ## 결과
  ## 관련
  ```
- status: `proposed | accepted | deprecated | superseded by [[NNNN-후속결정]]`
- 파일명: `decisions/NNNN-<kebab-case-제목>.md` (NNNN = 기존 파일 수 + 1)

**lessons/**:
- frontmatter: `date`, `tags:[lesson,<관련태그>]`, `project`, `summary:<1문장 요약>`, `confidence: high|medium|low`, `keywords:[<검색용 키워드 3-5개>]`
- 구조:
  ```
  # 교훈: <요약>
  ## 상황
  ## 문제
  ## 교훈
  ## 적용 방법
  (다음에 같은 상황이면 어떻게? 구체적 행동 지침)
  > [!warning] 주의
  > (무시하면 재발하는 문제)
  ## 관련
  ```
- confidence: 한 번 경험 = low, 반복 확인 = high
- 파일명: `lessons/YYYY-MM-DD-<kebab-case-요약>.md`

**resources/**:
- frontmatter: `date`, `tags:[resource,<관련태그>]`, `summary:<1문장 요약>`, `project:<관련 프로젝트>`, `topics:[<주제 키워드>]`
- 구조: `# <제목>` → `## 핵심 요약` → 내용 → `## 관련`
- `## 관련` 필수: 관련 프로젝트, 세션, area를 wikilink로 연결
- 파일명: `resources/<kebab-case-제목>.md`

**areas/<영역명>/**:
- 영역 폴더 없으면 생성. living doc (누적 업데이트).
- frontmatter: `date`, `tags:[area,<영역태그>]`, `summary:<1문장 요약>`
- 구조: `# <제목>` → 내용 → `## 관련`
- 파일명: `areas/<영역명>/<kebab-case-제목>.md`
- **area vs resource**: 앞으로 지식 누적 → area, 작성 시점 완결 → resource

**projects/<name>/**:
- 폴더 없으면 생성 + CLAUDE.md 포함.
- 프로젝트 ↔ area/resource 연결: 관련 노트 생성 시 `projects/<name>.md`의 해당 섹션에 wikilink 추가 (역방향도).

### git sync

노트 작성 후 반드시 실행:
```bash
cd $VAULT_DIR && git add decisions/ lessons/ resources/ areas/ projects/ && git commit -m "note: <타입> - <제목>" --quiet && git push --quiet &
```

실패해도 무시 (best-effort).

### 주의
- 사소한 내용은 기록하지 마라. **나중에 다시 찾을 가치가 있는 것만** 기록.
- 이미 비슷한 노트가 있으면 업데이트하라 (중복 생성 금지).
- 기록 시 사용자에게 한 줄로 알려라: "📝 vault에 기록: decisions/0001-jwt-strategy.md"
