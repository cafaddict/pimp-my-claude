---
name: daily
description: "하루 마무리 정리. 현재 세션 포함, 오늘 세션들을 종합하여 daily note 생성/업데이트."
allowed-tools: Read, Write, Glob, Grep, Bash
effort: high
---

## Daily Note 생성/업데이트

VAULT_DIR은 `~/Documents/vault` (환경변수 `CLAUDE_VAULT_DIR`으로 오버라이드 가능).

### 프로세스

#### 1. 현재 세션 먼저 저장

**이 세션은 아직 종료되지 않았으므로 세션이 자동 저장되지 않은 상태다.**
먼저 현재 세션의 내용을 sessions/에 저장하라:

- 파일명: `$VAULT_DIR/sessions/YYYY-MM-DD-HHMM-<topic>.md` (KST 한국시간 기준)
- 이번 대화에서 한 작업, 결정, TODO, **핵심 인사이트**를 요약하여 작성
- frontmatter에 `tags: [session]`, `date`, `cwd`, `summary`, `project`, `topics` 포함

이미 `-current.md` 또는 이 세션에 대한 파일이 있으면 업데이트.

#### 2. 오늘 세션 수집

오늘 날짜의 **모든** 세션 파일을 읽어라:
- `$VAULT_DIR/sessions/YYYY-MM-DD-*.md` (1단계에서 저장한 것 포함)

각 세션에서 추출:
- 작업 내용
- **핵심 인사이트**
- 결정사항
- 남은 TODO

#### 3. 기존 daily note 확인

`$VAULT_DIR/daily-notes/YYYY-MM-DD.md`가 이미 있으면:
- 기존 내용을 읽고
- 새로 추가된 세션만 반영하여 **업데이트**
- 사용자가 수동으로 추가한 내용(개인 메모 등)은 **보존**

없으면 새로 생성.

#### 4. Daily Note 형식 (SSoT 원칙)

**핵심: 내용을 복사하지 마라. wikilink로 참조하라.** sessions/, decisions/, lessons/가 진실의 원천.

```markdown
---
date: YYYY-MM-DD
tags: [daily]
summary: <오늘의 핵심 한 줄 요약>
---

# YYYY-MM-DD

## 오늘 한 일
- [세션별 핵심 작업 요약, 1-2줄씩 — 이것만 직접 작성]

## 오늘의 인사이트
(세션들의 ## 핵심 인사이트에서 가장 가치 있는 배움/발견 1-3개 큐레이션)
> [!tip] 핵심
> (가장 중요한 인사이트 1개)

## 남은 TODO
- [ ] [미완료 항목 종합]

## 세션
- [[YYYY-MM-DD-HHMM-topic]]

## 결정
- [[NNNN-결정제목]] ← 오늘 생성된 decisions/ 노트 (있으면)

## 교훈
- [[YYYY-MM-DD-교훈제목]] ← 오늘 생성된 lessons/ 노트 (있으면)

## 지식
- [[노트제목]] ← 오늘 생성된 areas/ 또는 resources/ 노트 (있으면)

## 이번 주 흐름
```dataview
TABLE summary
FROM "daily-notes"
WHERE date >= date(this.date) - dur(6 days) AND date <= date(this.date)
SORT date ASC
```

## 메모
[사용자가 자유롭게 추가 — 업데이트 시 보존]
```

실제 존재하는 파일만 wikilink. decisions/나 lessons/가 없으면 해당 섹션 비움.

#### 5. 역링크 추가

daily note 생성 후, 오늘의 각 세션 노트(`sessions/YYYY-MM-DD-*.md`)의 `## 관련` 섹션에 daily note wikilink(`[[YYYY-MM-DD]]`)를 추가하라.
이미 daily wikilink가 있으면 중복 추가하지 마라.

#### 6. git sync (통합 commit)

save-session이 stage만 해둔 변경사항을 포함하여 한번에 commit+push:
```bash
cd $VAULT_DIR && git add sessions/ daily-notes/ decisions/ lessons/ && git commit -m "daily: YYYY-MM-DD" --quiet && git push --quiet &
```

#### 7. 사용자에게 확인

정리된 daily note를 보여주고, 추가하고 싶은 내용이 있는지 물어라.
