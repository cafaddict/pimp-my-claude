---
name: save-session
description: |
  현재 세션을 vault에 저장. 세션 마무리 시 자동으로 사용하라.
  Use when: 사용자가 "끝", "마무리", "세션 저장", "오늘 여기까지" 등을 말할 때.
allowed-tools: Read, Write, Bash, Glob
effort: medium
---

## 세션 저장

### vault 경로 결정

vault 경로를 아래 순서로 결정:
1. 환경변수 `$CLAUDE_VAULT_DIR`이 설정되어 있으면 사용
2. 없으면 `~/Documents/vault/`를 기본값으로 사용
3. 해당 경로가 존재하지 않으면 사용자에게 경로를 물어라

### 저장 프로세스

1. vault 경로의 `sessions/` 디렉토리 확인 (없으면 생성)

2. 파일 생성:
   - 파일명: `sessions/YYYY-MM-DD-HHMM.md` (현재 시간)
   - 같은 파일이 있으면 초 단위 추가 (`-SS`)

3. 내용 작성:
```markdown
---
date: YYYY-MM-DD
tags: [session]
cwd: <현재 작업 디렉토리>
---

# 세션: YYYY-MM-DD HHMM

## 작업 디렉토리
`<cwd>`

## 작업 내용
(이번 세션에서 한 작업을 bullet point로, 3-7개)

## 결정사항
(내린 결정. 없으면 '없음')

## 남은 TODO
(미완료 항목 체크박스. 없으면 '없음')

## 관련
- [[YYYY-MM-DD]] ← 해당 날짜의 daily note
- [[프로젝트명]] ← 작업한 프로젝트 (있으면)
- [[YYYY-MM-DD-교훈제목]] ← 이 세션에서 생성된 교훈 (있으면)
```

**wikilink 규칙**: Obsidian 그래프 뷰를 위해 `## 관련` 섹션에 반드시 관련 노트 wikilink를 포함하라. 파일명만으로 링크 (shortest name). 링크 대상이 존재하지 않으면 링크하지 마라.

4. **결정사항 → decisions/ 자동 분리**:
   세션의 `## 결정사항`에 기록된 항목 중 아키텍처/기술 선택에 해당하는 것이 있으면,
   /note 스킬로 vault `decisions/`에 ADR 형식으로 자동 기록하라.
   - 이미 동일/유사한 decision이 vault에 있으면 skip (중복 방지)
   - 사소한 결정 (파일명 변경 등)은 기록하지 마라 — 재사용 가치 있는 것만

5. git sync:
```bash
cd <vault> && git add sessions/ decisions/ && git commit -m "session: YYYY-MM-DD HHMM" --quiet && git push --quiet
```
실패해도 무시.

### 주의
- 간결하게 작성. 대화 전체를 복사하지 마라.
- 이미 이 세션에 대한 파일이 있으면 업데이트.
