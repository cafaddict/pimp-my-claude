---
name: plain-words
description: "쉬운 단어로 쓰기. 설명 산문에서 논문식 한자 학술어(유휴, 축출, 상보적, 이질적)와 영어 격식어(utilize, facilitate, in order to)를 실무자가 쓰는 표현으로 바꾸고, 반대로 정착된 기술 용어(queue, TTFT, threshold, backpressure)는 억지 번역하지 않는다. \"쉽게 써줘\", \"쉬운 단어 좀 쓰자\", \"용어가 어렵다\", \"use simpler words\", \"plain language\", \"write clearly\" 요청 시 사용. 논문 리뷰·개념 설명·문서/README/커밋 메시지 등 산문을 쓸 때 언어 불문 적용."
effort: low
---

## 핵심 — 실패 모드는 두 개, 방향이 반대다

축은 **한국어 vs 영어가 아니다**. **실무자가 입으로 말하는 표현 vs 아닌 표현**이다.
"idle"은 영어인데 쉽다 (엔지니어가 매일 말한다). "유휴"는 한국어인데 어렵다 (논문에만 있다).

> **테스트: 이 분야 사람이 회의에서 이 단어를 소리 내어 말하는가?**
> 아니라면 틀린 단어다. 한자어든, 새로 만든 순우리말이든.

원칙: **기술 용어**는 실무자가 쓰는 형태(보통 영어/외래어)를 유지한다.
**설명 산문** — 논리를 나르는 문장 — 은 쉽고 구체적으로 쓴다.

---

## 실패 A — 논문식 한자 학술어

논문에는 나오지만 실무자는 입으로 말하지 않는 한자어. 풀어 쓰거나 영어를 그대로 쓴다.

| 쓰지 말 것 | 쓸 것 |
|---|---|
| 유휴 | idle |
| 축출 | evict |
| 상보적 | 서로 보완하는 / 각자 다른 부분을 맡는 |
| 이질적 | 서로 다른 |
| 상이한 | 서로 다른 |
| 정량화 | 숫자로 재기 |
| 귀결 | 결론 |
| 열화 | 나빠짐 / degradation |
| 은폐 | 숨김 |
| 강건성 | robust |
| 편익 | 이득 |
| 소거 | 상쇄 / 사라짐 |
| 반직관적 | 직관과 반대 / counterintuitive |
| 도출 | 뽑아냄 / 계산 |
| 병리적 | 이상한 |
| 급소 | 핵심 / 약점 |
| 관건 / 요체 | 핵심 |
| 야기 / 초래 | 일으킴 / 생김 |
| 기인하다 | ~때문이다 |
| 수반하다 | 같이 따라온다 |
| 상충 | 서로 충돌 |
| 저해 | 방해 |
| 제고 | 높임 |
| 상정 | 가정 |
| 소요되다 | 걸리다 |
| 상기한 / 전술한 | 위에서 말한 |
| 함의 | 뜻하는 바 |
| 전무하다 | 하나도 없다 |
| 여실히 | 분명히 |

---

## 실패 B — 정착된 기술 용어를 억지로 번역 (이게 더 나쁘다)

A보다 나쁘다. 독자의 **닻(anchor)을 빼앗기 때문**이다.
독자는 "queue"를 안다. "줄 밀림 비용"은 모른다. 새 단어를 배우게 만들면 더 어려워진다.

| 쓰지 말 것 (창작 번역) | 쓸 것 | 원어 |
|---|---|---|
| 줄 밀림 비용 | **큐잉 지연** | queueing delay |
| 대기줄 | **waiting 큐** | waiting queue |
| 딱지 | **타입 라벨** | type label |
| 들쭉날쭉함 | **CV** | coefficient of variation |
| 점검 주기 | **tick** | tick |
| 기준값 | **threshold** | threshold |
| 첫 토큰 지연 | **TTFT** | time to first token |
| 서버 바꿔 타는 비율 | **churn** | churn |
| 얼마나 노는가 | **idleness** | idleness |
| 자리 (메모리 계층) | **계층** | tier |
| 임시 저장소 | **캐시** | cache |
| 미리 가져오기 | **prefetch** | prefetch |
| 역압 | **backpressure** | backpressure |
| 간접비 | **오버헤드** | overhead |
| 치우침 | **skew** | skew |
| 문맥 교환 | **컨텍스트 스위치** | context switch |
| 쪽 결함 | **페이지 폴트** | page fault |
| 꼬리 지연 | **테일 레이턴시 / p99** | tail latency |
| 추측 해독 | **speculative decoding** | speculative decoding |
| 키-값 저장 | **KV 캐시** | KV cache |

판단이 애매하면 **원어를 남긴다**. 창작 번역보다 항상 안전하다.

---

## 첫 등장만 병기, 그 다음엔 맨몸으로

- 첫 등장: `idleness(얼마나 놀고 있나)`, `TTFT(첫 토큰 지연)`, `churn(서버를 바꿔 타는 비율)`
- 그 다음부터: `idleness`, `TTFT`, `churn`
- 매번 다시 병기하지 않는다. 반복 병기는 문장을 무겁게 만든다.

---

## English — 같은 병, 같은 처방

**실패 A (격식어 → 실무어):**

| 쓰지 말 것 | 쓸 것 |
|---|---|
| utilize | use |
| leverage (동사) | use |
| facilitate | help |
| endeavor | try |
| ascertain | find out |
| commence | start |
| elucidate | explain |
| demonstrate | show |
| necessitate | need |
| delve into | look at |
| in order to | to |
| prior to | before |
| subsequent to / subsequently | after / then |
| due to the fact that | because |
| in the event that | if |
| has the ability to | can |
| a number of | several / many |
| numerous / myriad | many |
| approximately | about |
| at this point in time | now |
| aforementioned | this / that |
| moreover / furthermore | also |
| methodology | method |
| paradigm | approach |
| it should be noted that | (삭제) |
| it is important to note that | (삭제) |
| robust (내용 없는 수식어) | (구체적으로 써라) |
| seamless (내용 없는 수식어) | (구체적으로 써라) |

**실패 B (영어도 똑같다):** 정착된 전문 용어를 구수한 말로 바꾸지 말 것.
`backpressure`는 `backpressure`다. "pushing-back pressure"가 아니다.
그대로 두는 것들: backpressure, throughput, tail latency, cache line, false sharing,
head-of-line blocking, cold start, thrashing, spill, fan-out, idempotent, eventual consistency.

**다른 언어:** 원칙만 그대로 적용한다 — 실무자가 말하는 등록어(register)를 쓰고,
정착된 용어에 대해 그 지역 언어 계어(calque)를 새로 만들지 않는다.

---

## Before / After

**1. 과잉 교정의 함정 (가장 중요)**

"쉽게 써줘"를 듣고 B 방향으로 넘어가면 더 나빠진다.

- 너무 어려움 (A): "유휴 상태의 워커가 이질적인 요청을 처리하면 큐잉 지연이 증가하고 처리량이 열화된다."
- **과잉 교정 (B, 더 나쁨):** "놀고 있는 일꾼이 서로 다른 부탁을 처리하면 줄 밀림 비용이 늘고 일 처리량이 나빠진다."
- 정답: "idle한 워커가 서로 다른 종류의 요청을 처리하면 **큐잉 지연**이 늘고 **처리량**이 떨어진다."

`워커`, `큐잉 지연`, `처리량`은 실무자가 말한다 → 유지.
`유휴 / 이질적 / 열화`는 말하지 않는다 → 교체.
`일꾼 / 부탁 / 줄 밀림 비용`은 아무도 말하지 않는다 → 창작 금지.

**2. 한국어 설명 산문**

- Before: "본 기법은 캐시 축출 정책의 강건성을 정량화하여 편익을 도출한다."
- After: "이 기법은 캐시 **evict** 정책이 얼마나 잘 버티는지 숫자로 재서 이득을 계산한다."

**3. 영어 산문**

- Before: "It should be noted that in order to facilitate robust performance, we utilize a number of heuristics prior to scheduling."
- After: "To keep tail latency stable, we use several heuristics before scheduling."

("robust performance"는 내용이 없으므로 무엇이 robust한지 구체화했다. `tail latency`, `heuristics`, `scheduling`은 실무어라 유지.)

---

## 건드리지 않는 것

- 코드, 식별자, API·함수·플래그 이름, CLI 명령, 에러 문자열 — **원문 그대로**.
- 인용문, 논문 제목, 저자 표기, 수식 기호.
- 확립된 약어(DMA, TLB, RDMA, MoE, SLO…) — 풀어 쓰지 않는다. 첫 등장에만 한 줄 뜻풀이.

## 하지 말 것

- **내용을 쉽게 만드는 게 아니다. 단어를 쉽게 만드는 것이다.** 정확성이나 깊이를 깎지 않는다.
- 단어를 바꿔서 뜻이 조금이라도 달라지면 바꾸지 않는다. 대신 원어 + 한 줄 설명.
- 유아어·구어체로 흐르지 않는다. 목표는 "쉬운 말"이 아니라 **실무자가 실제로 쓰는 말**이다.
- 문장을 길게 늘려 쉬운 척하지 않는다. 짧고 구체적인 문장이 쉽다.
