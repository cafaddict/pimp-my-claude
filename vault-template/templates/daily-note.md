---
date: {{date}}
tags: [daily]
summary:
---

# {{date}}

## 오늘 한 일
-

## 오늘의 인사이트
> [!tip] 핵심
> (세션에서 추출한 가장 가치 있는 배움)

## 남은 TODO
- [ ]

## 세션
%% YYYY-MM-DD-HHMM-topic 형식으로 wikilink 추가 %%

## 결정
%% NNNN-결정제목 형식으로 wikilink 추가 %%

## 교훈
%% YYYY-MM-DD-교훈제목 형식으로 wikilink 추가 %%

## 지식
%% 관련 area, resource 노트를 wikilink로 연결 %%

## 이번 주 흐름
```dataview
TABLE summary
FROM "daily-notes"
WHERE date >= date(this.date) - dur(6 days) AND date <= date(this.date)
SORT date ASC
```

## 메모

