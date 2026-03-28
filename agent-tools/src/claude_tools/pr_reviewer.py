"""PR 자동 리뷰 — Opus + 구조화 출력.

사용법:
    claude-review --repo owner/repo --pr 123
    claude-review --pr 123              # 현재 디렉토리의 repo 사용
    python -m claude_tools.pr_reviewer --pr 123
"""

from __future__ import annotations

import argparse
import asyncio
import json
import subprocess
import sys

from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query

from claude_tools.models import ReviewResult


def get_pr_diff(pr_number: int, repo: str | None = None) -> str:
    """gh CLI로 PR diff를 가져온다."""
    cmd = ["gh", "pr", "diff", str(pr_number)]
    if repo:
        cmd.extend(["--repo", repo])
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


def get_pr_info(pr_number: int, repo: str | None = None) -> str:
    """gh CLI로 PR 정보를 가져온다."""
    cmd = ["gh", "pr", "view", str(pr_number)]
    if repo:
        cmd.extend(["--repo", repo])
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


async def review_pr(
    pr_number: int,
    repo: str | None = None,
    max_budget: float = 3.0,
) -> ReviewResult:
    """PR을 리뷰하고 구조화된 결과를 반환한다."""
    diff = get_pr_diff(pr_number, repo)
    pr_info = get_pr_info(pr_number, repo)

    # diff가 너무 크면 잘라내기 (토큰 절약)
    max_diff_chars = 50_000
    if len(diff) > max_diff_chars:
        diff = diff[:max_diff_chars] + "\n\n... (diff truncated, review visible portion)"

    prompt = f"""다음 PR을 리뷰해주세요.

## PR 정보
{pr_info}

## 변경사항 (diff)
```
{diff}
```

## 리뷰 관점
1. **정확성**: 로직이 의도대로 동작하는가? 엣지 케이스?
2. **보안**: 인젝션, 인증 우회, 민감 데이터 노출?
3. **성능**: 불필요한 연산, N+1, 메모리 누수?
4. **테스트**: 변경에 대한 테스트가 충분한가?

각 이슈에 severity(critical/warning/suggestion)와 category를 지정하세요.
"""

    async for message in query(
        prompt=prompt,
        options=ClaudeAgentOptions(
            permission_mode="plan",
            max_turns=5,
            max_budget_usd=max_budget,
            output_format={
                "type": "json_schema",
                "schema": ReviewResult.model_json_schema(),
            },
        ),
    ):
        if isinstance(message, ResultMessage) and message.subtype == "success":
            if message.structured_output:
                return ReviewResult.model_validate(message.structured_output)

    raise RuntimeError("리뷰 결과를 받지 못했습니다.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Claude PR 자동 리뷰")
    parser.add_argument("--pr", type=int, required=True, help="PR 번호")
    parser.add_argument("--repo", type=str, default=None, help="owner/repo (생략 시 현재 디렉토리)")
    parser.add_argument("--budget", type=float, default=3.0, help="최대 비용 (USD)")
    parser.add_argument("--json", action="store_true", help="JSON 출력")
    args = parser.parse_args()

    try:
        result = asyncio.run(review_pr(args.pr, args.repo, args.budget))
    except subprocess.CalledProcessError as e:
        print(f"gh CLI 에러: {e.stderr}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(result.model_dump_json(indent=2))
    else:
        print(f"\n## PR #{args.pr} 리뷰 결과\n")
        print(f"**판정**: {result.overall_assessment}")
        print(f"**요약**: {result.summary}\n")

        for issue in result.issues:
            location = f"`{issue.file_path}"
            if issue.line:
                location += f":{issue.line}"
            location += "`"

            print(f"**[{issue.severity.value.upper()}]** {location} — {issue.description}")
            if issue.suggestion:
                print(f"> {issue.suggestion}")
            print()


if __name__ == "__main__":
    main()
