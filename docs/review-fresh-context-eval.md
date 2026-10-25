# 새 맥락 리뷰(`context: fork`) 작은 비교 실험

같은 세션에서 만든 변경을 그 세션 안에서 `/review`하면, 리뷰어가 작성할 때의 근거(잘못된 근거 포함)를
그대로 본다. 공식 best practices는 새 subagent 맥락의 리뷰를 권한다. 이 레포의 `review` skill에
`context: fork`를 붙이면 그렇게 되는지, 품질·비용이 어떻게 달라지는지 작은 과제로 비교했다.
**결론: 이 과제에서는 품질 차이를 관찰하지 못했고 비용은 늘었다. review skill은 바꾸지 않는다.**

## 과제와 채점

- fixture: 백업 보존 함수 `select_for_deletion` 하나와 요구사항 R1~R6을 적은 `SPEC.md`(경계값 포함 여부,
  pinned를 호출자가 넘긴 경우, 반환 순서, 입력 리스트 변경 금지까지 문구로 확정).
- 미commit 변경에 결함 4개를 심었다. R2(정확히 max_age_days인 백업 삭제)와 R3(함수 안 pinned 검사 없음)는
  1턴의 "구현 메모"가 그럴듯하게 정당화한다(anchored). R4(최신순 반환)와 R6(입력 리스트 정렬)는 메모에 없다.
  기존·신규 테스트는 모두 통과하며, 별도 oracle로 결함 4개와 R1·R5 충족을 확인했다.
- 세션 2턴: 1턴 "네가 구현했다 + 메모 + 테스트만 돌려 봐", 2턴 `/review SPEC.md 기준… FINDING: R<번호> | … 형식`.
- 채점(실행 전 확정·해시 기록): FINDING 줄이 인용한 R 번호로 결함 탐지, R1·R5 인용은 오탐. 리뷰 뒤 작업 트리 불변 확인.

## 실행 조건

Mac의 Claude Code 2.1.310, `claude-opus-5-5`, effort medium. 두 실행군은 플래그가 같고
`.claude/skills/review/SKILL.md`의 frontmatter 두 줄(`context: fork`, `background: false`)만 다르다.
`--setting-sources project`, `disableAllHooks`, sandbox(작업 폴더 밖 쓰기·네트워크 차단), `--strict-mcp-config`,
CLAUDE.md 없음. 매 실행 새 임시 사본, init 기록으로 사용자 skill·plugin·MCP·hook이 없음을 확인했다.
pair 3개, pair 안 순서는 무작위.

## 결과

**1차 (사전 규칙대로 채점):** 기존(inline) anchored 6/6, unanchored 6/6. fork 0/6, 0/6.
fork 실행군은 FINDING 줄을 하나도 쓰지 않았다. forked subagent가 받은 prompt에 `/review` 뒤의 문장이 없었다.
**본문에 `$ARGUMENTS`가 없는 `context: fork` skill은 사용자 인자를 subagent에 넘기지 않는다**(본문의 `$0`
치환만 된다). 결과를 본 뒤 사람이 읽은 판독으로는 fork 리뷰 3개 모두 결함 4개를 본문에 보고했다.
이 판독은 사전 점수를 대체하지 않는다. 1차는 지시 전달 차이가 섞여 맥락 격리 효과를 재지 못했다.

**2차 (양쪽 본문에 `- 요청·기준: $ARGUMENTS` 한 줄을 똑같이 추가, 실행 전 재등록):**

| 지표 (pair 3개 합) | 기존(inline) | fork |
|---|---|---|
| anchored 결함 탐지 (R2·R3) | 6/6 | 6/6 |
| unanchored 결함 탐지 (R4·R6) | 6/6 | 6/6 |
| 오탐 (R1·R5 인용) | 0 | 0 |
| 작업 트리 변경 | 없음 | 없음 |
| wall time 합 | 140.95초 | 145.43초 (+3.2%) |
| 출력 토큰 합 | 10,949 | 11,559 (+5.6%) |
| cache creation 토큰 합 | 46,110 | 65,842 (+42.8%) |
| cache read 토큰 합 | 307,378 | 273,541 (−11.0%) |
| CLI 추정 비용 합 | $0.6495 | $0.7012 (+8.0%) |
| 2턴 main thread API 토큰 합(실행별) | 55,363 / 75,265 / 76,092 | 0 / 0 / 0 |

- 토큰·비용은 CLI의 세션 누적값(fork subagent 포함)이다. 비용은 추정값이며 청구 증빙이 아니다.
- "2턴 main thread API 토큰 합"은 리뷰 턴에서 main thread가 쓴 API 호출 토큰의 합이다. 맥락 크기 자체가 아니다.
  fork는 리뷰 탐색을 subagent에서 하므로 0이다. 리뷰 결과 문장은 main 대화로 돌아온다.
- 보이는 도구 호출은 기존 실행마다 main 3회, fork는 main 1~3회 + subagent 2회였다. 내부 API 호출 수는 모른다.
- 1차까지 포함한 12회 비교 실행의 추정 비용 합은 $2.68이다(설정 확인용 probe 실행 제외).

## 판단

- 메모가 잘못된 근거를 대도 같은 세션 리뷰가 6/6을 찾았다. 이 과제에서는 "작성 근거에 끌린다"는 실패가 나타나지 않았다.
  천장 효과일 수 있고, 과제 1개·pair 3개·모델 1개라 일반화할 수 없다. 효과는 **미검증**이다.
- fork는 비용이 조금 더 들고, 인자 누락, 대화 의도를 못 보는 점, interactive 기본 background 실행 같은 실패 조건이 있다.
  그래서 `review` skill의 기본 동작은 그대로 둔다.
- 반영한 것: fork skill이 `$ARGUMENTS`를 참조하는지 보는 검사(`tests/test-installers.sh`, `harness-tester`).

## 다시 실행하려면

위 조건대로 깨끗한 임시 사본에 fixture를 만들고, 두 skill 파일을 프로젝트 `.claude/skills/review/`에 번갈아 넣어
`claude -p --input-format stream-json --output-format stream-json --verbose`로 같은 2턴을 보낸다.
부모 Claude 세션 안에서 돌리면 `CLAUDE_CODE_SAFE_MODE` 같은 환경 변수가 상속되어 프로젝트 skill이 로드되지 않는다.
init 기록의 `skills`에 `review`가 있는지 먼저 확인한다. 채점 기준은 실행 전에 고정하고, 요구사항 문구에 없는 조건은 채점하지 않는다.

## 출처 (확인 2026-10-25)

- [Anthropic: Best practices](https://code.claude.com/docs/en/best-practices) (게시일 미표시):
  "Add an adversarial review step", Writer/Reviewer, 계획 대비 리뷰는 직접 프롬프트를 쓰라는 안내.
- [Anthropic: Skills](https://code.claude.com/docs/en/skills) (게시일 미표시): `context: fork`, `background`, 같은 이름 규칙.
- [openai/codex `review.rs`](https://github.com/openai/codex/blob/main/codex-rs/core/src/tasks/review.rs) (최신 커밋 2026-10-10):
  Codex 내장 리뷰도 부모 대화 기록 없이(`initial_history None`) reviewer를 띄운다.
- [obra/superpowers requesting-code-review](https://github.com/obra/superpowers/blob/main/skills/requesting-code-review/SKILL.md)
  (2026-10-10): "never your session's history"라고 적은 공개 구현.

## 적용과 복구

소스 문서만 추가했다. skill 동작, 설치 스크립트, hook, 홈 설정은 바뀌지 않는다. 되돌리려면 이 문서를 추가한 커밋을 revert한다.
