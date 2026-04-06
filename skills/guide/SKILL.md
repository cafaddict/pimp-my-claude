---
name: guide
description: "설치된 기능 전체 가이드. 사용 가능한 스킬, 훅, 에이전트, 플러그인을 보여줌."
allowed-tools: Read, Bash, Glob
effort: medium
---

## 작업

아래 디렉토리들을 Bash 도구(`ls`)로 탐색하라:
1. `$HOME/.claude/skills/` — 각 하위 디렉토리의 SKILL.md를 Read로 읽어 name과 description 추출
2. `$HOME/.claude/hooks/` — 파일명과 첫 줄 주석에서 설명 추출
3. `$HOME/.claude/agents/` — 에이전트 목록
4. `$CLAUDE_VAULT_DIR` (미설정 시 `$HOME/Documents/vault/`) — vault 디렉토리 구조 확인

아래 형식으로 정리:

### Skills
| 스킬 | 설명 | 사용법 | 자동 호출 |
|------|------|--------|----------|
(자동 호출: Claude가 알아서 사용하는지 여부)

### Hooks
| 훅 | 이벤트 | 설명 |
|----|--------|------|

### Vault (Second Brain)
| 디렉토리 | 용도 | 자동 기록 |
|----------|------|----------|
| sessions/ | 세션 기록 | save-session 스킬 |
| lessons/ | 교훈/삽질 기록 | ✅ note 스킬 자동 |
| decisions/ | 아키텍처 의사결정 | ✅ note 스킬 자동 |
| projects/ | 프로젝트별 지식 | ✅ note 스킬 자동 / init-project.sh |
| resources/ | 참고 자료 | ✅ note 스킬 자동 |
| areas/ | 지속 관리 영역 | 수동 |
| daily-notes/ | 일일 노트 | 수동 |

### 유용한 팁
- `& 프롬프트`: 원격 샌드박스에서 무거운 분석 오프로드
- `/doctor`: 환경 문제 자동 진단
- `/context`: 현재 컨텍스트 사용량 확인
- `Ctrl+G`: 외부 에디터에서 긴 프롬프트 작성
- `Shift+Tab` 두 번: Plan Mode 진입
- `/compact`: 컨텍스트 압축
- `init-project.sh`: 프로젝트별 rules/ + vault 프로젝트 초기화

마지막에: "더 자세히 알고 싶은 기능이 있으면 `/스킬명`을 입력하세요."
