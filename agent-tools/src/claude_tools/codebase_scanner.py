"""코드베이스 보안/품질 스캔 — Opus + 구조화 출력.

사용법:
    claude-scan --dir ./src
    claude-scan --dir ./src --budget 5.0
    python -m claude_tools.codebase_scanner --dir ./src
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query

from claude_tools.models import ScanResult


async def scan_codebase(
    directory: str,
    max_budget: float = 5.0,
) -> ScanResult:
    """디렉토리를 OWASP Top 10 기준으로 보안 스캔한다."""
    dir_path = Path(directory).resolve()
    if not dir_path.is_dir():
        raise FileNotFoundError(f"디렉토리가 존재하지 않습니다: {directory}")

    prompt = f"""다음 디렉토리를 보안 관점에서 스캔하세요: {dir_path}

## 스캔 기준 (OWASP Top 10 + 추가)
1. **인젝션** (SQL, Command, XSS, LDAP)
2. **인증 취약점** (하드코딩된 시크릿, 약한 패스워드 정책)
3. **민감 데이터 노출** (로그에 시크릿, 에러 메시지에 내부 정보)
4. **접근 제어** (인가 검사 누락, IDOR)
5. **보안 설정 오류** (디버그 모드, 기본 자격증명)
6. **암호화** (약한 알고리즘, 평문 전송)
7. **입력 검증** (타입 검사 누락, 범위 초과)
8. **의존성** (알려진 취약점이 있는 라이브러리)
9. **로깅** (부적절한 에러 핸들링, 정보 누출)
10. **SSRF/경로 탐색** (사용자 입력 기반 파일/URL 접근)

## 지시사항
- 소스 파일들을 읽고 분석하세요
- 각 취약점에 CWE ID, severity, 파일 위치, 수정 방안을 포함하세요
- risk_score는 발견된 취약점의 종합 위험도 (0=안전, 100=위험)
- scanned_files에 실제로 분석한 파일 수를 기록하세요
"""

    async for message in query(
        prompt=prompt,
        options=ClaudeAgentOptions(
            permission_mode="plan",
            max_turns=15,
            max_budget_usd=max_budget,
            allowed_tools=["Read", "Grep", "Glob"],
            setting_sources=["project"],
            output_format={
                "type": "json_schema",
                "schema": ScanResult.model_json_schema(),
            },
        ),
    ):
        if isinstance(message, ResultMessage) and message.subtype == "success":
            if message.structured_output:
                return ScanResult.model_validate(message.structured_output)

    raise RuntimeError("스캔 결과를 받지 못했습니다.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Claude 코드베이스 보안 스캔")
    parser.add_argument("--dir", type=str, required=True, help="스캔할 디렉토리")
    parser.add_argument("--budget", type=float, default=5.0, help="최대 비용 (USD)")
    parser.add_argument("--json", action="store_true", help="JSON 출력")
    args = parser.parse_args()

    try:
        result = asyncio.run(scan_codebase(args.dir, args.budget))
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(result.model_dump_json(indent=2))
    else:
        print(f"\n## 보안 스캔 결과\n")
        print(f"**위험도**: {result.risk_score}/100")
        print(f"**스캔 파일 수**: {result.scanned_files}")
        print(f"**요약**: {result.summary}\n")

        if not result.vulnerabilities:
            print("취약점이 발견되지 않았습니다.")
        else:
            print(f"### 취약점 ({len(result.vulnerabilities)}개)\n")
            for vuln in result.vulnerabilities:
                cwe = f" ({vuln.cwe_id})" if vuln.cwe_id else ""
                location = f"`{vuln.file_path}"
                if vuln.line:
                    location += f":{vuln.line}"
                location += "`"

                print(f"**[{vuln.severity.upper()}]{cwe}** {location}")
                print(f"  {vuln.description}")
                print(f"  > 수정: {vuln.remediation}")
                print()


if __name__ == "__main__":
    main()
