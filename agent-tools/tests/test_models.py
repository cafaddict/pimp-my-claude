"""Pydantic 모델 검증 테스트."""

import pytest
from claude_tools.models import (
    Category,
    DailyChange,
    DailyReport,
    ReviewIssue,
    ReviewResult,
    ScanResult,
    SecurityVulnerability,
    Severity,
)


class TestReviewModels:
    def test_review_issue_minimal(self) -> None:
        issue = ReviewIssue(
            severity=Severity.WARNING,
            category=Category.SECURITY,
            file_path="src/auth.py",
            description="SQL injection 가능성",
        )
        assert issue.severity == Severity.WARNING
        assert issue.line is None
        assert issue.suggestion is None

    def test_review_issue_full(self) -> None:
        issue = ReviewIssue(
            severity=Severity.CRITICAL,
            category=Category.CORRECTNESS,
            file_path="src/main.cpp",
            line=42,
            description="널 포인터 역참조",
            suggestion="std::optional 사용 권장",
        )
        assert issue.line == 42
        assert issue.suggestion is not None

    def test_review_result_approve(self) -> None:
        result = ReviewResult(
            summary="깔끔한 코드입니다.",
            issues=[],
            overall_assessment="approve",
        )
        assert result.overall_assessment == "approve"
        assert len(result.issues) == 0

    def test_review_result_request_changes(self) -> None:
        result = ReviewResult(
            summary="보안 이슈가 있습니다.",
            issues=[
                ReviewIssue(
                    severity=Severity.CRITICAL,
                    category=Category.SECURITY,
                    file_path="src/api.py",
                    line=10,
                    description="하드코딩된 API 키",
                ),
            ],
            overall_assessment="request_changes",
        )
        assert len(result.issues) == 1
        assert result.issues[0].severity == Severity.CRITICAL

    def test_review_result_json_roundtrip(self) -> None:
        result = ReviewResult(
            summary="테스트",
            issues=[],
            overall_assessment="comment",
        )
        json_str = result.model_dump_json()
        restored = ReviewResult.model_validate_json(json_str)
        assert restored == result


class TestScanModels:
    def test_vulnerability_minimal(self) -> None:
        vuln = SecurityVulnerability(
            severity="high",
            file_path="src/db.py",
            description="SQL injection",
            remediation="파라미터 바인딩 사용",
        )
        assert vuln.cwe_id is None

    def test_vulnerability_with_cwe(self) -> None:
        vuln = SecurityVulnerability(
            cwe_id="CWE-89",
            severity="critical",
            file_path="src/db.py",
            line=25,
            description="SQL injection",
            remediation="파라미터 바인딩 사용",
        )
        assert vuln.cwe_id == "CWE-89"

    def test_scan_result_clean(self) -> None:
        result = ScanResult(
            vulnerabilities=[],
            risk_score=0,
            summary="취약점 없음",
            scanned_files=50,
        )
        assert result.risk_score == 0

    def test_scan_result_risk_score_bounds(self) -> None:
        with pytest.raises(Exception):
            ScanResult(
                vulnerabilities=[],
                risk_score=101,
                summary="invalid",
            )


class TestDailyReportModels:
    def test_daily_change(self) -> None:
        change = DailyChange(
            file_path="src/main.py",
            change_type="modified",
            summary="로깅 추가",
            author="hyunyul",
        )
        assert change.change_type == "modified"

    def test_daily_report_empty(self) -> None:
        report = DailyReport(
            date="2026-03-28",
            total_commits=0,
            total_files_changed=0,
        )
        assert report.highlights == []
        assert report.risks == []

    def test_daily_report_full(self) -> None:
        report = DailyReport(
            date="2026-03-28",
            total_commits=5,
            total_files_changed=12,
            changes=[
                DailyChange(
                    file_path="src/auth.py",
                    change_type="modified",
                    summary="JWT 토큰 갱신 로직 수정",
                ),
            ],
            highlights=["인증 모듈 리팩토링"],
            risks=["JWT 만료 처리 변경 — 기존 세션 영향 가능"],
        )
        assert report.total_commits == 5
        assert len(report.risks) == 1

    def test_daily_report_json_roundtrip(self) -> None:
        report = DailyReport(
            date="2026-03-28",
            total_commits=1,
            total_files_changed=1,
        )
        json_str = report.model_dump_json()
        restored = DailyReport.model_validate_json(json_str)
        assert restored == report
