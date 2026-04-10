---
name: vault-add-project
description: "프로젝트 초기화. .claude/rules/ 설치 + vault 프로젝트 폴더 생성."
argument-hint: "[언어...] (예: cpp python, 기본: cpp python)"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
effort: medium
---

## 프로젝트 초기화 프로토콜

현재 작업 디렉토리를 Claude Code 프로젝트로 초기화하고, vault에 프로젝트 지식 폴더를 생성한다.

VAULT_DIR: `$CLAUDE_VAULT_DIR` (미설정 시 `~/Documents/vault`)
PIMP_MY_CLAUDE_DIR: 아래 순서로 탐색:
1. `{{REPO_DIR}}`
2. `~/Documents/pimp-my-claude`
3. 없으면 rules-templates 설치 건너뜀

### 1. 인수 파싱

`$ARGUMENTS`에서 언어 목록을 추출한다.
- 예: `cpp python` → ["cpp", "python"]
- 인수 없으면 기본값: ["cpp", "python"]
- 사용 가능한 언어: pimp-my-claude 레포의 `rules-templates/` 디렉토리에서 `.md` 확장자 제외한 파일명 목록

### 2. .claude/rules/ 설치

현재 디렉토리에 `.claude/rules/` 생성 후, pimp-my-claude 레포의 `rules-templates/`에서 해당 언어 룰 파일을 복사한다.

- 언어별 룰: `rules-templates/<lang>.md` → `.claude/rules/<lang>.md`
- testing 룰: `rules-templates/testing.md` → `.claude/rules/testing.md` (항상 포함)
- 템플릿이 없는 언어가 요청되면 경고 출력하고 건너뜀

### 3. vault 프로젝트 폴더 생성

프로젝트명 = 현재 디렉토리의 `basename`.

`$VAULT_DIR/projects/<프로젝트명>/` 이 이미 존재하면:
- "vault 프로젝트 이미 존재" 안내 후 건너뜀

존재하지 않으면 아래 2개 파일을 생성:

#### 3-1. CLAUDE.md

```markdown
# 프로젝트: <프로젝트명>

## 개요


## 기술 스택


## 레포 경로
`<현재 디렉토리 절대 경로>`

## 핵심 결정


## 메모

```

#### 3-2. <프로젝트명>.md

vault-notes 규칙의 project frontmatter 스키마를 따른다:

```markdown
---
date: <오늘 날짜 YYYY-MM-DD>
tags: [project]
status: active
repo: <git remote get-url origin, 없으면 빈 문자열>
---

# 프로젝트: <프로젝트명>

## 개요


## 기술 스택


## 관련 결정
-

## 관련 세션
-

```

### 4. 자동 감지로 노트 보강

프로젝트 디렉토리를 분석하여 생성된 노트에 정보를 채운다:
- `git remote get-url origin` → repo 필드
- README.md가 있으면 첫 단락을 개요에 반영
- CMakeLists.txt, pyproject.toml, package.json 등으로 기술 스택 추론
- 디렉토리 구조 간략 요약

### 5. vault git 커밋

vault가 git 레포이면:
```bash
cd $VAULT_DIR && git stash && git pull --rebase && git stash pop && git add projects/<프로젝트명>/ && git commit -m "project: init <프로젝트명>" && git push
```
- `git stash`에 stash할 내용이 없으면 (clean 상태) stash pop도 생략
- **sync 실패 시 원인을 파악하고 해결한 뒤 진행하라. 실패를 무시하고 넘어가지 마라.**

### 6. 결과 표시

```
=== 프로젝트 초기화 완료 ===
  .claude/rules/: cpp.md python.md testing.md
  vault: projects/<프로젝트명>/
```
