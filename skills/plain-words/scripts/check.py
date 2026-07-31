#!/usr/bin/env python3
"""plain-words 검사기 — 산문에서 어려운 단어를 찾아 대체어를 제안한다.

단어 목록을 코드에 박지 않고 ../SKILL.md의 대조표를 런타임에 파싱한다.
SKILL.md가 유일한 출처이므로 표를 고치면 검사기가 자동으로 따라온다.
(caveman의 활성화 훅이 SKILL.md를 런타임에 읽는 것과 같은 이유 — 중복은 반드시 낡는다.)

사용법:
    python check.py FILE...          # 파일 검사
    python check.py --list           # 파싱된 규칙 확인
    cat x.md | python check.py -     # stdin 검사

종료 코드: 0 = 깨끗함, 1 = 지적 있음 (CI/훅에서 사용 가능)

검사 대상은 산문뿐이다. 다음은 건너뛴다:
    - 코드 블록 (``` 펜스), 인라인 코드 (`...`)
    - 인용 (> 로 시작하는 줄), 링크 URL
    - SKILL.md의 대조표 자체 (표 문법 줄)
괄호로 조건이 붙은 표 항목("자리 (메모리 계층)", "robust (내용 없는 수식어)")은
판단이 필요하므로 기계 검사에서 제외한다 — 오탐이 나면 아무도 검사기를 쓰지 않는다.

단어를 인용하는 문서(이 스킬의 문서처럼)는 마커로 제외한다:
    <!-- plain-words: ignore-file -->   파일 전체 제외
    ... <!-- plain-words: ignore -->    그 줄만 제외
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.join(HERE, "..", "SKILL.md")

# Windows 콘솔 기본 코드페이지(cp949/cp1252)에서 한글·화살표 출력이 깨지는 것을 막는다.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

IGNORE_FILE = "<!-- plain-words: ignore-file -->"
IGNORE_LINE = "<!-- plain-words: ignore -->"

SECTIONS = [
    ("## 실패 A", "A", "논문식 한자어"),
    ("## 실패 B", "B", "억지 번역 — 원어를 유지할 것"),
    ("## English", "E", "영어 격식어"),
]


def parse_tables(path):
    """SKILL.md에서 (범주, 나쁜 표현, 대체어) 목록을 뽑는다."""
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    rules, cat, label = [], None, None
    for line in lines:
        if line.startswith("## "):
            cat = label = None
            for prefix, c, l in SECTIONS:
                if line.startswith(prefix):
                    cat, label = c, l
        if cat is None or not line.startswith("|"):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        bad, good = cells[0], cells[1]
        if not bad or set(bad) <= set("-: "):          # 구분선
            continue
        if bad in ("쓰지 말 것", "쓰지 말 것 (창작 번역)", "Claude writes"):
            continue
        if "(" in bad:                                  # 조건부 항목 → 판단 필요
            continue

        good = good.replace("*", "").strip()
        for term in re.split(r"\s*/\s*", bad.replace("*", "")):
            term = term.strip()
            if term:
                rules.append((cat, label, term, good))
    return rules


def strip_noncontent(text):
    """코드/인용/URL을 공백으로 치환해 위치를 유지하면서 검사에서 제외한다."""
    def blank(m):
        return re.sub(r"\S", " ", m.group(0))

    text = re.sub(r"```.*?```", blank, text, flags=re.S)     # 펜스 코드 블록
    text = re.sub(r"`[^`\n]*`", blank, text)                 # 인라인 코드
    text = re.sub(r"^\s*>.*$", blank, text, flags=re.M)      # 인용
    text = re.sub(r"^\s*\|.*$", blank, text, flags=re.M)     # 표 (대조표 자체)
    text = re.sub(r"https?://\S+", blank, text)              # URL
    return text


def check(text, rules):
    if IGNORE_FILE in text:
        return []
    lines = strip_noncontent(text).splitlines()
    hits = []
    for n, line in enumerate(lines, 1):
        if IGNORE_LINE in line:
            continue
        for cat, label, bad, good in rules:
            if bad.isascii():
                pat = r"\b" + re.escape(bad) + r"\b"
                found = re.search(pat, line, re.I)
            else:
                found = re.search(re.escape(bad), line)
            if found:
                hits.append((n, cat, label, bad, good))
    return hits


def main():
    ap = argparse.ArgumentParser(description="plain-words 어휘 검사기")
    ap.add_argument("files", nargs="*", help="검사할 파일 ('-' 는 stdin)")
    ap.add_argument("--list", action="store_true", help="파싱된 규칙만 출력")
    ap.add_argument("--quiet", action="store_true", help="종료 코드만 (출력 없음)")
    args = ap.parse_args()

    if not os.path.exists(SKILL):
        print("SKILL.md 를 찾을 수 없음: %s" % SKILL, file=sys.stderr)
        return 2
    rules = parse_tables(SKILL)

    if args.list:
        for cat, label, bad, good in rules:
            print("%s  %-28s → %s" % (cat, bad, good))
        print("\n총 %d개 규칙 (A=%d, B=%d, E=%d)" % (
            len(rules),
            sum(1 for r in rules if r[0] == "A"),
            sum(1 for r in rules if r[0] == "B"),
            sum(1 for r in rules if r[0] == "E"),
        ))
        return 0

    if not args.files:
        ap.print_help()
        return 2

    total = 0
    for path in args.files:
        if path == "-":
            text, name = sys.stdin.read(), "<stdin>"
        else:
            if not os.path.isfile(path):
                print("건너뜀 (파일 아님): %s" % path, file=sys.stderr)
                continue
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            name = path

        hits = check(text, rules)
        total += len(hits)
        if hits and not args.quiet:
            print("\n%s" % name)
            for n, cat, label, bad, good in hits:
                print("  %d: [%s] %s → %s   (%s)" % (n, cat, bad, good, label))

    if not args.quiet:
        if total:
            print("\n%d개 지적. B 범주는 원어를 유지하라는 뜻이다 "
                  "(창작 번역 금지)." % total)
        else:
            print("깨끗함.")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
