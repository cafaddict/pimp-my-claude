---
name: guide
description: "설치된 기능 전체 가이드. 사용 가능한 스킬, 훅, 에이전트, 플러그인을 보여줌."
disable-model-invocation: true
---

## 현재 환경 상태

### 설치된 Skills
!`ls ~/.claude/skills/ 2>/dev/null`

### 설치된 Hooks
!`ls ~/.claude/hooks/ 2>/dev/null`

### 설치된 Agents
!`ls ~/.claude/agents/ 2>/dev/null`

## 작업

위 디렉토리 목록을 기반으로, 각 skill의 SKILL.md를 Read 도구로 읽어서 name과 description을 추출하라.
각 hook은 파일명과 첫 줄 주석에서 설명을 추출하라.

아래 형식으로 정리:

### Skills
| 스킬 | 설명 | 사용법 |
|------|------|--------|

### Hooks
| 훅 | 이벤트 | 설명 |
|----|--------|------|

### 유용한 팁
- `& 프롬프트`: 원격 샌드박스에서 무거운 분석 오프로드
- `/doctor`: 환경 문제 자동 진단
- `/context`: 현재 컨텍스트 사용량 확인
- `Ctrl+G`: 외부 에디터에서 긴 프롬프트 작성
- `Shift+Tab` 두 번: Plan Mode 진입
- `/compact`: 컨텍스트 압축

마지막에: "더 자세히 알고 싶은 기능이 있으면 `/스킬명`을 입력하세요."
