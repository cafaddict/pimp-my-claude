---
name: vault-save
description: |
  현재 세션을 vault에 저장. 세션 마무리 시 자동으로 사용하라.
  Use when: 사용자가 "끝", "마무리", "세션 저장", "오늘 여기까지" 등을 말할 때.
allowed-tools: Read, Write, Bash, Glob
effort: medium
---

## 세션 저장

VAULT_DIR: 환경변수 `$CLAUDE_VAULT_DIR` 또는 `~/Documents/vault/` (경로 없으면 사용자에게 질문).

### 저장 프로세스

1. vault 경로의 `sessions/` 디렉토리 확인 (없으면 생성)

2. 파일 생성:
   - 파일명: `sessions/YYYY-MM-DD-HHMM-<topic>.md` (**KST 한국시간 기준**)
   - `<topic>`: 세션 핵심 주제를 kebab-case 2-4단어 (예: `vault-quality-improvement`)
   - 시간 확인: `date +%Y-%m-%d-%H%M -d '+9 hours'` (UTC 시스템) 또는 `TZ=Asia/Seoul date +%Y-%m-%d-%H%M`
   - 같은 파일이 있으면 초 단위 추가 (`-SS`)

3. 내용 작성:
```markdown
---
date: YYYY-MM-DD
tags: [session, <프로젝트태그>]
cwd: <현재 작업 디렉토리>
project: <프로젝트명 또는 빈 값>
summary: <1문장 핵심 요약>
topics: [<2-5개 주제 키워드>]
---

# 세션: YYYY-MM-DD HHMM — <한 줄 제목>

## 작업 내용
(이번 세션에서 한 작업을 bullet point로, 3-7개)

## 핵심 인사이트
(이 세션에서 얻은 가장 중요한 깨달음, 배움, 발견. 없으면 '없음')
(단순 "무엇을 했다"가 아니라 "왜 그랬고, 무엇을 배웠는가")

> [!tip] 핵심
> (가장 재사용 가치 높은 인사이트 1개)

## 결정사항
(내린 결정과 간략한 이유. 없으면 '없음')

## 남은 TODO
(미완료 항목 체크박스. 없으면 '없음')

## 관련
- [[프로젝트명]] ← 작업한 프로젝트 (있으면)
- [[YYYY-MM-DD-교훈제목]] ← 이 세션에서 생성된 교훈 (있으면)
```

4. **wikilink 규칙**:
   - Glob으로 vault 내 파일 존재 확인 후 링크. 존재하지 않는 파일은 절대 링크하지 마라.
   - daily note(`[[YYYY-MM-DD]]`)는 링크하지 마라 — daily가 session을 역링크한다.
   - 프로젝트 노트가 존재하면 해당 노트의 `## 관련 세션`에 이 세션 wikilink를 추가하라 (양방향 링크).

5. **결정사항 → decisions/ 자동 분리**:
   세션의 `## 결정사항`에 기록된 항목 중 아키텍처/기술 선택에 해당하는 것이 있으면,
   /vault-note 스킬로 vault `decisions/`에 ADR 형식으로 자동 기록하라.
   - 이미 동일/유사한 decision이 vault에 있으면 skip (중복 방지)
   - 사소한 결정 (파일명 변경 등)은 기록하지 마라 — 재사용 가치 있는 것만

6. git sync:
```bash
cd <vault> && git pull --rebase && git add sessions/ decisions/ projects/ && git commit -m "session: YYYY-MM-DD-HHMM-<topic>" && git push
```

### 주의
- 간결하되 인사이트는 빠뜨리지 마라. "뭘 했다"만은 부실.
- 이미 이 세션에 대한 파일이 있으면 업데이트.
