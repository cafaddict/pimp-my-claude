---
name: perf
description: "성능 분석 및 최적화. 느린 코드, 메모리 이슈, 병목 분석."
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
effort: high
---

## 성능 분석 프로토콜

### 1. 현상 정리
- 어떤 동작이 느린가? (응답 시간, 처리량, 메모리 사용량)
- 측정 가능한 수치 확인 (프로파일링, 벤치마크, 로그 타임스탬프)
- 기대 성능 vs 실제 성능 수치 명시

### 2. 병목 식별
- 프로파일링 도구 실행
  - C++: perf, valgrind, gprof
  - Python: cProfile, py-spy, memory_profiler
- Hot path 식별 (실행 시간 기준 상위 함수)
- I/O bound vs CPU bound 판별

### 3. 원인 분석
- 알고리즘 복잡도 문제? (O(n²) → O(n log n) 가능?)
- 불필요한 복사/할당? (C++: move semantics, Python: generator)
- 캐싱 가능한 반복 연산?
- I/O 병목? (DB 쿼리, 네트워크, 디스크)
- 메모리 관련? (누수, 과도한 할당, fragmentation)

### 4. 최적화 제안
- 각 제안에 **예상 개선 효과** 명시
- **트레이드오프** 설명 (가독성, 메모리, 복잡도)
- 가장 임팩트 큰 것부터 순서대로 나열
- 측정 없이 추측하지 않음

### 5. 구현 및 검증
- 최적화 적용 후 동일 벤치마크 재실행
- **전후 수치 비교** 테이블 제시
- 회귀 테스트 통과 확인
- 가독성/유지보수성 저하 여부 검토

### Vault 기록
최적화 패턴과 전후 벤치마크 수치를 /note 스킬로 vault에 기록하라.
- 특정 프로젝트에 한정된 최적화 → `resources/`
- 지속적으로 축적할 성능 관련 지식 → `areas/<관련영역>/`
전후 수치(개선율)를 반드시 포함하라.
