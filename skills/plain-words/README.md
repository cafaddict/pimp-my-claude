# plain-words

어려운 단어를 쓰지 않게 만드는 스킬. 그리고 **"쉽게 써줘"를 들었을 때 반대 방향으로
과잉 교정하지 않게** 막는 스킬.

> `setup.sh`는 `SKILL.md`만 `~/.claude/skills/`로 복사한다. 이 README는 설계 근거 문서다.

## 왜 만들었나

한국어로 시스템 논문을 읽으며 Claude와 대화하던 중, Claude의 한국어가 읽기 어려웠다.
"쉬운 단어 좀 쓰자"고 하니 Claude가 **반대 방향으로 과잉 교정**했다 — 정착된 기술 용어에
없던 순우리말 번역을 만들어내기 시작했고, 결과는 더 나빠졌다.

- Claude: "줄 밀림 비용이 늘어난다"
- 사용자: "que를 줄로 번역하면 이해하기 더 어렵지 않을까?"

여기서 규칙이 드러났다. 실패 모드가 **두 개**이고, 처방이 **반대**다.

| | 증상 | 예 | 처방 |
|---|---|---|---|
| **A** | 논문식 한자 학술어 | 유휴, 축출, 상보적, 이질적, 열화 | 풀어 쓰거나 영어로 (idle, evict) |
| **B** | 정착된 용어를 창작 번역 | 줄 밀림 비용, 대기줄, 기준값, 딱지 | 원어 유지 (큐잉 지연, threshold) |

B가 더 나쁘다. 독자의 닻을 빼앗기 때문이다. 독자는 `queue`를 알고 `줄 밀림 비용`은 모른다.

축은 **한국어 vs 영어가 아니다**. `idle`은 영어지만 쉽다(엔지니어가 매일 말한다).
`유휴`는 한국어지만 어렵다(논문에만 있다). 축은 **실무자가 말하는가 아닌가**다.

테스트 한 줄: **"이 분야 사람이 회의에서 이 단어를 소리 내어 말하는가?"**

영어에도 같은 병이 있다 (utilize, facilitate, "it should be noted that"), 그리고 같은
B 함정이 있다 — `backpressure`를 "pushing-back pressure"로 바꾸면 안 된다.

## 설치

`./setup.sh` 를 실행하면 세 조각이 함께 설치된다.

| 조각 | 위치 | 동작 |
|---|---|---|
| 스킬 | `~/.claude/skills/plain-words/SKILL.md` | 필요할 때 로드 (전체 대조표 + 예시) |
| 전역 rule | `~/.claude/rules/plain-words.md` | 매 세션 시작에 항상 로드 (요약 15줄) |
| 훅 | `~/.claude/hooks/plain-words-remind.sh` | 매 턴 재주입 (**기본 켜짐**) |
| 검사기 | `skills/plain-words/scripts/check.py` (레포에 남음) | 파일로 쓴 산문을 기계 검사 |

훅은 기본 켜져 있다. 단어 선택은 요청받고 하는 작업이 아니라 상시 습관이기 때문이다.
비용은 프롬프트당 176자, 대략 100~150 토큰 (문자 수는 측정, 토큰 수는 추정).
코딩 위주 세션에서 노이즈면 끈다.

```bash
touch ~/.claude/.plain-words-off   # 끄기
rm ~/.claude/.plain-words-off      # 다시 켜기
```

수동 호출: `/plain-words`

`setup.sh`는 `SKILL.md`만 복사하므로 `scripts/check.py`는 클론한 레포에 남는다.
SKILL.md 안의 `{{REPO_DIR}}`가 설치 시점에 레포 경로로 치환되므로 Claude가 경로를 안다.

```bash
python <repo>/skills/plain-words/scripts/check.py docs/*.md   # 검사
python <repo>/skills/plain-words/scripts/check.py --list      # 규칙 84개 확인
```

검사기는 `SKILL.md`의 대조표를 **런타임에 파싱**한다. 표를 고치면 검사기가 따라오므로
단어 목록이 두 곳에서 갈라지지 않는다 (caveman이 활성화 훅에서 SKILL.md를 읽는 것과 같은 이유).
코드 블록·인라인 코드·인용·표는 건너뛴다. 단어를 인용하는 문서는
`<!-- plain-words: ignore-file -->` 또는 줄 끝 `<!-- plain-words: ignore -->`로 제외한다.

## 왜 조각이 세 개인가 (정직한 한계)

**스킬만으로는 "항상 이렇게 써라"가 안 된다.** 스킬은 frontmatter `description`을 보고
모델이 관련 있다고 판단할 때 로드되는 **온디맨드** 메커니즘이다. 매 응답 보장이 아니다.
단어 선택은 "요청이 있을 때 하는 작업"이 아니라 상시 습관이므로 미스매치가 생긴다.

그래서 계층을 나눴다.

1. **rule (항상 로드)** — path frontmatter가 **없는** rule은 CLAUDE.md와 같은 우선순위로
   세션 시작에 무조건 로드된다. 그래서 요약본은 rule에 둔다. 다만 rule도 *컨텍스트*이지
   강제가 아니고, 긴 세션에서는 드리프트하며 compaction 때 잘려나갈 수 있다.

   > `plain-words.md`에 frontmatter를 일부러 넣지 않았다. path 스코프 rule은 버그 이력이
   > 있다 — 문서가 안내하는 `paths:`는 인용/YAML 리스트 형태에서 조용히 로드되지 않고
   > ([#17204](https://github.com/anthropics/claude-code/issues/17204)), 사용자 레벨
   > `~/.claude/rules/`의 `paths:`는 무시된다
   > ([#21858](https://github.com/anthropics/claude-code/issues/21858)).
   > 두 이슈 모두 **frontmatter 없는 rule은 정상 로드**된다고 확인했다. 즉 이 스킬이 쓰는
   > 형태가 유일하게 버그 이력이 없는 경로다. (레포의 다른 rule들이 쓰는 `globs:`는
   > 문서에 없지만 실제로 동작하는 형태다 — 바꾸지 않았다.)
2. **스킬 (온디맨드)** — 전체 대조표는 무겁다. 항상 로드하면 낭비다. "쉽게 써줘" 같은
   명시적 요청이나 문서 작성 시 로드되게 두는 게 맞다.
3. **훅 (매 턴, 기본 켜짐)** — 실제로 매 턴 적용해 긴 세션의 문체 drift를 막는다. `UserPromptSubmit`
   훅의 `additionalContext`는 Claude가 프롬프트를 보기 전에 주입된다. 프롬프트당 176자를
   쓰지만, 1·2번이 보장하지 못하는 부분을 이것만 메운다. 끄고 싶으면 플래그 파일로 끈다.

이 계층 설계는 [caveman](https://github.com/juliusbrussee/caveman)에서 검증된 패턴을
따랐다. caveman의 활성화 훅 주석에 그 이유가 적혀 있다 — 짧은 요약만 주입했을 때
"models drifted back to verbose mid-conversation, especially after context compression
pruned it away."

**Output style은 쓰지 않았다.** 현재 Claude Code 문서에 output style이 존재하지 않는다.
없는 기능 위에 얹으면 동작하는 척만 하는 물건이 된다.

**4번째 조각(검사기)은 계층이 아니다.** 1~3은 Claude가 쓰는 순간에 작동하고,
검사기는 이미 파일로 쓴 뒤에 확인하는 용도다. 대조표에 있는 단어만 잡는다.

## 범위 밖

- 코드, 식별자, API/함수/플래그 이름, CLI 명령, 에러 문자열, 인용문, 논문 제목 — 원문 유지.
- 내용을 쉽게 만드는 스킬이 아니다. **단어**를 쉽게 만든다. 정확성/깊이는 깎지 않는다.
- 대조표는 한국어·영어만 열거했다. 다른 언어는 원칙만 적용한다 (실무자가 말하는 등록어를
  쓰고, 정착된 용어에 새 계어를 만들지 않는다). 언어별 표를 추측으로 채우지 않았다.
- 대조표에 있는 단어만 기계 검사가 잡는다. 표에 없는 어려운 단어는 사람/Claude의 판단
  영역이다 (검사기는 판단을 대신하지 않는다).
- 저장 시점 자동 검사(PostToolUse 훅)는 넣지 않았다. 문서를 쓸 때마다 훅이 돌면
  코드 편집과 섞여 노이즈가 된다. 필요하면 각자 붙일 수 있게 스크립트만 제공한다.

<!-- plain-words: ignore-file -->
