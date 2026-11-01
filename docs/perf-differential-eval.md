# 최적화 전 참조 구현 대조: 작은 테스트 설계 비교

2026-11-01, 기존 `perf` 지침에 differential 검사 절차를 추가할지 비교했다.
**양쪽 모두 고정 결함 4개를 감지했다. 기본 skill은 바꾸지 않는다.**
이것은 AI 활용법의 작은 실험이며 hook/vault 유지보수나 버전 갱신이 아니다.

## 후보와 기존 동작

`perf`는 프로파일링, 병목 분석, 같은 benchmark 재실행과 회귀 검사를 요구한다.
후보는 최적화 전에 간단한 참조 구현을 보존하고, 명세의 제한된 입력 공간에서
정확한 반환값·순서·입력 불변을 비교한 뒤 차이를 작은 재현 사례로 줄이는 절차다.
집계·정렬 최적화에서 유용할 가설이지만 참조 구현도 틀릴 수 있고, 입력 범위와
부동소수 허용오차가 계약에 맞아야 한다. 별도 skill·wrapper·패키지는 추가하지 않았다.
기존 TDD의 기능 부재 확인, review의 발견 검증, 지난 검증 원장과는 목적이 다르다.

## 성공 실행 전에 고정한 과제·기준

`latest(rows, cutoff)`의 명세:

- `rows`는 `[key, timestamp]` 쌍의 리스트. key는 정수 0..2, timestamp/cutoff는 정수 -2..2.
- timestamp >= cutoff인 행만 남기고 key별 가장 큰 timestamp를 선택한다.
- 결과는 key 오름차순의 `[key, timestamp]` 리스트. 입력을 바꾸지 않는다.
- 빈 입력은 빈 결과. 같은 key의 같은 timestamp는 동일 record다.

참조 구현:

```python
def latest(rows, cutoff):
    result = {}
    for key, timestamp in rows:
        if timestamp >= cutoff:
            result[key] = max(timestamp, result.get(key, timestamp))
    return sorted([key, timestamp] for key, timestamp in result.items())
```

두 조건 모두 이 명세·참조와 기존 `skills/perf/SKILL.md` 전체를 받았다.
과제는 향후 빠른 구현의 의미 오류를 잡는 구체 사례를 최대 12개 제안하는 것이다.
JSON의 각 사례는 `rows`, `cutoff`, 정확한 `expected`를 가지며 별도 `rationale`을 쓴다.
도구·파일·외부 접근 없이 JSON만 반환하고 실행했다고 주장하지 않도록 요청했다.
후보에만 다음 절차를 추가했다(실행 프롬프트는 영어).

> 시간 측정 전에 단순 참조를 보존하고 명세에서 도출한 제한된 생성 입력으로 대조한다.
> 정확한 값과 순서, 입력 보존을 별도로 검사한다. 경계·반복 key 배열을 포함하고
> 불일치를 작은 재현으로 줄인다. 계약을 몰래 바꾸거나 명시 범위 밖의 참조를 믿지 않는다.
> 이번에는 실행할 수 없으므로 도움이 될 구체 사례를 고르고 실행 대기임을 밝힌다.

유효성 기준은 JSON, 최대 12개, 명세 범위와 참조에 맞는 expected다.
무효 사례는 점수에 쓰지 않는다. 고정 mutant는 다음 네 가지다.

1. `>= cutoff`를 `> cutoff`로 바꿈.
2. key별 최대 대신 마지막 qualifying timestamp를 선택함.
3. 결과의 key 순서를 뒤집음.
4. 먼저 `rows.sort()`로 입력을 바꾸고 올바른 결과를 반환함.

유효 사례를 각 mutant에 실제 실행해 감지한 mutant 수를 4점 만점으로 센다.
입력 변경은 rationale이 입력 보존 검사를 요청한 경우에만 검사하기로 고정했다.
후보만 더 많이 감지하고 참조 오탐이 없을 때 작은 실험적 통합을 고려하며,
동률·악화이면 기본 skill을 유지하기로 했다. 성공 실행 뒤 기준을 바꾸거나 반복하지 않았다.

사전 파일 SHA-256(비공개 실행 자료와 대조용):

- baseline: `6507e07548496fe0e79368b2a92a2b81650fe4a585490fc5452a4ba9fb27e7f1`
- candidate: `e070307a2557a921eeb6443f934d87c8b4d088e14f0de74c972a569ce4a1eed1`
- protocol: `a2fd025716bbc1b3882b1e639ddcce8f44dd77daa5f4d00de595a1b5f9335a60`

## 실제 실행과 결과

Mac에 설치된 Codex CLI 0.162.1을 각 조건 1회, 기존→후보 순서로 실행했다.
동일 임시 HOME, `exec --ignore-user-config --ephemeral --sandbox read-only --json`,
180초 제한과 동일 작업 경로를 사용했다. 기존 native 인증 제공자만 사용했고 인증 값은
읽거나 복사하지 않았다. CLI는 로컬 Mac에서 실행했으며 Codex Cloud 작업은 사용하지 않았다.
모델 추론은 서비스에서 처리된다. 모델/effort를 지정하지 않았고 JSON 이벤트에 실제 선택값이
없어 **정확한 모델·effort는 미확인**이다. 같게 요청했지만 같은 backend라는 검증은 아니다.

| 지표 | 기존 | 후보 |
|---|---:|---:|
| 종료 코드 | 0 | 0 |
| 유효 사례 / 잘못된 expected | 12 / 0 | 12 / 0 |
| 감지 mutant | 4/4 | 4/4 |
| 올바른 참조 통과 | 12/12 | 12/12 |
| 입력 불변 검사 요청 | 있음 | 있음 |
| 경과 시간(초) | 17.256 | 16.387 |
| 입력 토큰 | 14,968 | 15,064 |
| 캐시 입력(입력의 일부) | 12,288 | 12,288 |
| 출력 토큰 | 872 | 785 |
| reasoning 출력 토큰 | 119 | 43 |
| 완료 turn / 보이는 도구 호출 | 1 / 0 | 1 / 0 |

캐시 쓰기 입력은 양쪽 0이다. 토큰은 `turn.completed.usage` 관측값이고 내부 API 호출 수·
청구 비용은 모른다. 양쪽 모두 미실행/실행 대기를 명시했다. 모델이 테스트를 실행한 것이
아니며, 반환된 JSON 사례를 평가자가 Python으로 참조와 mutant에 실행한 결과다.
예를 들어 양쪽의 `[[2,2],[0,2],[1,2]]` 계열은 경계·순서·입력 변경을,
최댓값 뒤에 작은 timestamp가 오는 반복 key 사례는 마지막 값 선택 오류를 잡았다.
사전 파일 해시는 실행 뒤 모두 일치했다.

## 해석과 적용

후보의 추가 가치를 관찰하지 못했다. `perf`에 지침을 추가하거나 새 skill을 만들지 않는다.
시간 차이와 출력 감소도 1회 관측이며 속도·비용 개선의 증거로 쓰지 않는다.
실제 성능 최적화, benchmark, property generator 실행, 자동 skill 선택은 시험하지 않았다.
이 비교는 **대조 기법 자체보다 그 지침이 구체 테스트 설계에 주는 추가 가치**만 좁게 본다.

1과제·1pair, 고정 순서, 같은 모델 계열의 설계/채점, 쉬운 명세와 천장 효과,
후보가 더 길고 구체적이라는 교란, 공통 CLI 기본 지침, 모델 선택 미확인이 한계다.
따라서 differential 검사가 쓸모없다는 결론도 내리지 않는다. 필요한 작업에서는 사용자가
명시적으로 참조·입력 범위·검증 명령을 주고 요청할 수 있다. 이번 기본 설정 변경은 없다.

다시 비교하려면 위 명세와 당시 `perf` 본문을 같은 프롬프트로 주고 후보에만 위 절차를
추가한다. 모델·effort를 실행 전 고정하고 새 사본에서 같은 mutant 기준으로 채점한다.
이는 후속 개선 제안이며 이번 결과를 소급해서 바꾸지 않는다.
소스 복구는 이 문서와 README 링크를 추가한 커밋을 revert하면 된다. 홈 배포는 필요 없다.

## 출처와 다른 후보 (접근 2026-11-01)

- [OpenAI Codex prompting](https://learn.chatgpt.com/docs/prompting)와
  [Claude best practices](https://code.claude.com/docs/en/best-practices):
  명세·제약·검증을 제공하는 공식 지침. 게시일 미표시이며 효과 비교 증거는 아니다.
- [Anthropic property-based testing 연구](https://www.anthropic.com/research/property-based-testing)
  (2026-01-14): AI의 속성 선택·검사와 수동 검증 사례를 보고한다. 저자의 실사용 자기보고이며
  개인 프로젝트 효과로 일반화하지 않는다. 잘못된 속성으로 생긴 dateutil 오탐도 공개했다.
- [Hypothesis 공개 구현](https://hypothesis.readthedocs.io/en/latest/_modules/hypothesis/extra/ghostwriter.html):
  `equivalent`의 같은 입력 반환값 대조와 별도 오류 동등성 옵션을 실제 코드에서 확인했다.
  렌더 버전 6.170.14, 코드 게시/커밋 날짜 미확인. 외부 코드는 설치·실행하지 않았다.
- [agentic-pbt 공개 지침](https://github.com/mmaaz-git/agentic-pbt/blob/main/hypo.md):
  빠른 구현과 단순 구현 대조, 계약에 근거한 속성 선정과 오탐 분류를 확인했다.
  커밋 날짜 미표시, 설치·실행하지 않았다. 논문 당시 코드와 main은 다르다는 README 안내가 있다.
- [aws-powertools PR #7246](https://github.com/aws-powertools/powertools-lambda-python/pull/7246):
  반복 첫 chunk 문제의 실제 수정, 2025-08-28 merge 확인. AI 발견 기여는 연구 저자 설명에 의존한다.
- 관계 검사(roundtrip/split-reconstruct)는 변환의 기대값을 일일이 쓰기 어려울 때 유용할
  후보지만 손실 변환에 잘못된 관계를 적용하면 오탐이다. 별도 실험 비용 때문에 보류했다.
- [Hypothesis stateful tests](https://hypothesis.readthedocs.io/en/latest/stateful.html)는
  동작과 값을 함께 생성하는 실제 예제를 제공한다(6.170.14, 게시일 미표시).
  cache/queue의 연속 동작 검사는 기존 debug 가설 분담과 다르지만 모델·시간 의미 관리 비용이
  커 이번에는 보류했다. 패키지·runner를 설치하지 않았다.

기존 Discussion #4의 검증 원장, Goals, skill eval, 근거 리뷰, 게시 분리, 새 맥락/교차 모델 리뷰,
인터뷰 우선은 신규 후보로 세지 않았다. 사용 빈도가 없어 기존 skill/hook/agent는 유지한다.
대체 동등성과 설치 영향을 입증하지 못한 항목의 삭제도 없다.
