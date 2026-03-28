---
name: daily
description: "하루 마무리 정리. 현재 세션 포함, 오늘 세션들을 종합하여 daily note 생성/업데이트."
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Bash
effort: high
---

## Daily Note 생성/업데이트

VAULT_DIR은 `~/Documents/vault` (환경변수 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

### 프로세스

#### 1. 현재 세션 먼저 저장

**이 세션은 아직 종료되지 않았으므로 session-save hook이 동작하지 않은 상태다.**
먼저 현재 세션의 내용을 sessions/에 저장하라:

- 파일명: `$VAULT_DIR/sessions/YYYY-MM-DD-HHMM-current.md`
- 이번 대화에서 한 작업, 결정, TODO를 요약하여 작성
- frontmatter에 `tags: [session]`, `date`, `cwd` 포함

이미 `-current.md` 파일이 있으면 업데이트.

#### 2. 오늘 세션 수집

오늘 날짜의 **모든** 세션 파일을 읽어라:
- `$VAULT_DIR/sessions/YYYY-MM-DD-*.md` (1단계에서 저장한 current 포함)

각 세션에서 추출:
- 작업 디렉토리
- 작업 내용
- 결정사항
- 남은 TODO

#### 3. 기존 daily note 확인

`$VAULT_DIR/daily-notes/YYYY-MM-DD.md`가 이미 있으면:
- 기존 내용을 읽고
- 새로 추가된 세션만 반영하여 **업데이트**
- 사용자가 수동으로 추가한 내용(개인 메모 등)은 **보존**

없으면 새로 생성.

#### 4. Daily Note 형식

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

## 세션
- [[YYYY-MM-DD-HHMM]] ← 오늘의 각 세션에 wikilink
- [[YYYY-MM-DD-HHMM]] ← 세션이 여러 개면 모두 나열

## 교훈
- [[YYYY-MM-DD-교훈제목]] ← 오늘 생성된 lesson 노트에 wikilink (있으면)

## 메모
[사용자가 자유롭게 추가하는 영역 — 업데이트 시 보존]
```

**wikilink 규칙**: `## 세션`과 `## 교훈` 섹션에 반드시 해당 날짜의 세션/교훈 노트를 `[[파일명]]`으로 연결하라. 실제 존재하는 파일만 링크.

#### 5. git sync

작성/업데이트 후:
```bash
cd $VAULT_DIR && git add sessions/ daily-notes/ && git commit -m "daily: YYYY-MM-DD" --quiet && git push --quiet &
```

#### 6. 사용자에게 확인

정리된 daily note를 보여주고, 추가하고 싶은 내용이 있는지 물어라.
