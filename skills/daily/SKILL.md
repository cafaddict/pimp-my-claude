---
name: daily
description: "하루 마무리 정리. 오늘 세션들을 종합하여 daily note 생성/업데이트."
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Bash
effort: high
---

## Daily Note 생성/업데이트

VAULT_DIR은 `~/Documents/vault` (환경변수 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

### 프로세스

#### 1. 오늘 세션 수집

오늘 날짜의 세션 파일들을 읽어라:
- `$VAULT_DIR/sessions/YYYY-MM-DD-*.md` (오늘 날짜)

각 세션에서 추출:
- 작업 디렉토리
- 작업 내용
- 결정사항
- 남은 TODO

#### 2. 기존 daily note 확인

`$VAULT_DIR/daily-notes/YYYY-MM-DD.md`가 이미 있으면:
- 기존 내용을 읽고
- 새로 추가된 세션만 반영하여 **업데이트**
- 사용자가 수동으로 추가한 내용(개인 메모 등)은 보존

없으면 새로 생성.

#### 3. Daily Note 형식

```markdown
---
date: YYYY-MM-DD
tags: [daily]
---

# YYYY-MM-DD

## 오늘 한 일
- [세션별 핵심 작업 요약, 1-2줄씩]

## 주요 결정
- [오늘 내린 결정들]

## 배운 것
- [교훈, 새로 알게 된 것]

## 남은 TODO
- [ ] [미완료 항목 종합]

## 메모
[사용자가 자유롭게 추가하는 영역 — 업데이트 시 보존]
```

#### 4. git sync

작성/업데이트 후:
```bash
cd $VAULT_DIR && git add daily-notes/ && git commit -m "daily: YYYY-MM-DD" --quiet && git push --quiet &
```

#### 5. 사용자에게 확인

정리된 daily note를 보여주고, 추가하고 싶은 내용이 있는지 물어라.
