"""구조화된 출력을 위한 Pydantic 모델."""

from __future__ import annotations

from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


# --- PR Review ---


class Severity(str, Enum):
    CRITICAL = "critical"
    WARNING = "warning"
    SUGGESTION = "suggestion"


class Category(str, Enum):
    CORRECTNESS = "correctness"
    SECURITY = "security"
    PERFORMANCE = "performance"
    TEST_COVERAGE = "test_coverage"
    STYLE = "style"


class ReviewIssue(BaseModel):
    """코드 리뷰에서 발견된 개별 이슈."""

    severity: Severity
    category: Category
    file_path: str
    line: int | None = None
    description: str
    suggestion: str | None = None


class ReviewResult(BaseModel):
    """PR 리뷰 전체 결과."""

    summary: str = Field(description="리뷰 요약 (2-3문장)")
    issues: list[ReviewIssue] = Field(default_factory=list)
    overall_assessment: Literal["approve", "request_changes", "comment"] = Field(
        description="전체 판정"
    )


# --- Security Scan ---


class SecurityVulnerability(BaseModel):
    """보안 취약점."""

    cwe_id: str | None = Field(None, description="CWE ID (예: CWE-79)")
    severity: Literal["critical", "high", "medium", "low", "info"]
    file_path: str
    line: int | None = None
    description: str
    remediation: str = Field(description="수정 방안")


class ScanResult(BaseModel):
    """코드베이스 보안 스캔 결과."""

    vulnerabilities: list[SecurityVulnerability] = Field(default_factory=list)
    risk_score: int = Field(ge=0, le=100, description="위험도 점수 0-100")
    summary: str
    scanned_files: int = 0


# --- Daily Report ---


class DailyChange(BaseModel):
    """일일 코드 변경 항목."""

    file_path: str
    change_type: Literal["added", "modified", "deleted", "renamed"]
    summary: str
    author: str | None = None


class DailyReport(BaseModel):
    """일일 코드 변경 리포트."""

    date: str
    total_commits: int
    total_files_changed: int
    changes: list[DailyChange] = Field(default_factory=list)
    highlights: list[str] = Field(
        default_factory=list, description="주요 변경사항 (3-5개)"
    )
    risks: list[str] = Field(
        default_factory=list, description="주의가 필요한 변경사항"
    )
