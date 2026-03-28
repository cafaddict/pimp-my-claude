"""일일 코드 변경 요약 리포트 — Opus + 구조화 출력.

사용법:
    claude-report
    claude-report --since "2 days ago"
    claude-report --repo owner/repo --json
    python -m claude_tools.daily_report
"""

from __future__ import annotations

import argparse
import asyncio
import json
import subprocess
import sys

from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query

from claude_tools.models import DailyReport


def get_git_log(since: str = "1 day ago", repo_dir: str | None = None) -> str:
    """git log를 가져온다."""
    cmd = [
        "git", "log",
        f"--since={since}",
        "--pretty=format:%H|%an|%ae|%s|%ai",
        "--stat",
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=repo_dir,
        check=True,
    )
    return result.stdout


def get_git_diff_stat(since: str = "1 day ago", repo_dir: str | None = None) -> str:
    """git diff --stat을 가져온다."""
    cmd = ["git", "diff", f"HEAD@{{{since}}}", "--stat"]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=repo_dir,
    )
    return result.stdout


async def generate_daily_report(
    since: str = "1 day ago",
    repo_dir: str | None = None,
    max_budget: float = 2.0,
) -> DailyReport:
    """일일 변경 리포트를 생성한다."""
    git_log = get_git_log(since, repo_dir)

    if not git_log.strip():
        from datetime import date
        return DailyReport(
            date=date.today().isoformat(),
            total_commits=0,
            total_files_changed=0,
            highlights=["변경사항 없음"],
        )

    diff_stat = get_git_diff_stat(since, repo_dir)

    prompt = f"""다음 git 로그를 분석하여 일일 리포트를 작성하세요.

## Git Log (since: {since})
```
{git_log}
```

## Diff Stat
```
{diff_stat}
```

## 지시사항
- date: 오늘 날짜 (YYYY-MM-DD)
- highlights: 가장 중요한 변경사항 3-5개 (비개발자도 이해할 수 있게)
- risks: 주의가 필요한 변경 (보안, 성능, 호환성 이슈)
- changes: 주요 파일 변경 목록
"""

    async for message in query(
        prompt=prompt,
        options=ClaudeAgentOptions(
            permission_mode="plan",
            max_turns=5,
            max_budget_usd=max_budget,
            output_format={
                "type": "json_schema",
                "schema": DailyReport.model_json_schema(),
            },
        ),
    ):
        if isinstance(message, ResultMessage) and message.subtype == "success":
            if message.structured_output:
                return DailyReport.model_validate(message.structured_output)

    raise RuntimeError("리포트 생성에 실패했습니다.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Claude 일일 변경 리포트")
    parser.add_argument("--since", type=str, default="1 day ago", help="기간 (기본: 1 day ago)")
    parser.add_argument("--dir", type=str, default=None, help="Git 레포 디렉토리")
    parser.add_argument("--budget", type=float, default=2.0, help="최대 비용 (USD)")
    parser.add_argument("--json", action="store_true", help="JSON 출력")
    args = parser.parse_args()

    try:
        result = asyncio.run(generate_daily_report(args.since, args.dir, args.budget))
    except subprocess.CalledProcessError as e:
        print(f"git 에러: {e.stderr}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(result.model_dump_json(indent=2))
    else:
        print(f"\n## 일일 리포트 ({result.date})\n")
        print(f"**커밋**: {result.total_commits}개 | **변경 파일**: {result.total_files_changed}개\n")

        if result.highlights:
            print("### 주요 변경사항")
            for h in result.highlights:
                print(f"- {h}")
            print()

        if result.risks:
            print("### 주의 필요")
            for r in result.risks:
                print(f"- {r}")
            print()

        if result.changes:
            print("### 변경 파일")
            for c in result.changes:
                print(f"- [{c.change_type}] `{c.file_path}` — {c.summary}")


if __name__ == "__main__":
    main()
