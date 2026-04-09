"""Hybrid search: BM25 (FTS5) + vector (sqlite-vec) + RRF fusion."""

import json
import re
import sqlite3
from collections import defaultdict
from dataclasses import dataclass

from indexer import serialize_f32


@dataclass
class SearchResult:
    path: str
    type: str
    title: str
    summary: str
    date: str
    project: str | None
    tags: list[str]
    score: float
    snippet: str


def _build_fts_query(query: str) -> str:
    """Build an FTS5 query from a natural language string.

    Escapes special characters and joins terms with implicit OR.
    """
    tokens = re.findall(r"\w+", query)
    if not tokens:
        return query
    escaped = [f'"{t}"' for t in tokens]
    return " OR ".join(escaped)


def _bm25_search(
    conn: sqlite3.Connection, query: str, limit: int
) -> list[tuple[int, float, str]]:
    """Return (doc_id, bm25_score, snippet) from FTS5."""
    fts_query = _build_fts_query(query)
    try:
        rows = conn.execute(
            """
            SELECT d.id,
                   bm25(documents_fts, 1.0, 1.5, 0.5, 0.8) AS score,
                   snippet(documents_fts, 2, '', '', '...', 32) AS snip
            FROM documents_fts
            JOIN documents d ON d.id = documents_fts.rowid
            WHERE documents_fts MATCH ?
            ORDER BY score
            LIMIT ?
            """,
            (fts_query, limit),
        ).fetchall()
    except sqlite3.OperationalError:
        return []
    return [(r[0], r[1], r[2]) for r in rows]


def _vector_search(
    conn: sqlite3.Connection, query_vec, limit: int
) -> list[tuple[int, float, str]]:
    """Return (doc_id, distance, chunk_text) via sqlite-vec. Best chunk per doc."""
    # Step 1: knn search on vec0 (no JOINs allowed)
    vec_rows = conn.execute(
        """
        SELECT rowid, distance, doc_id, chunk_idx
        FROM chunks_vec
        WHERE embedding MATCH ?
            AND k = ?
        """,
        (serialize_f32(query_vec), limit),
    ).fetchall()

    if not vec_rows:
        return []

    # Step 2: fetch chunk text separately
    by_doc: dict[int, tuple[float, str]] = {}
    for _, distance, doc_id, chunk_idx in vec_rows:
        if doc_id in by_doc:
            continue
        row = conn.execute(
            "SELECT text FROM chunks WHERE doc_id = ? AND chunk_idx = ?",
            (doc_id, chunk_idx),
        ).fetchone()
        text = row[0] if row else ""
        by_doc[doc_id] = (distance, text)

    return [(doc_id, dist, text) for doc_id, (dist, text) in by_doc.items()]


def _rrf_fuse(
    bm25_ranking: list[int],
    vec_ranking: list[int],
    k: int = 60,
) -> dict[int, float]:
    """Reciprocal Rank Fusion. Returns {doc_id: rrf_score}."""
    scores: dict[int, float] = defaultdict(float)
    for rank, doc_id in enumerate(bm25_ranking, start=1):
        scores[doc_id] += 1.0 / (k + rank)
    for rank, doc_id in enumerate(vec_ranking, start=1):
        scores[doc_id] += 1.0 / (k + rank)
    return dict(scores)


def _load_doc_metadata(conn: sqlite3.Connection, doc_ids: list[int]) -> dict[int, dict]:
    """Load document metadata for given IDs."""
    if not doc_ids:
        return {}
    placeholders = ",".join("?" * len(doc_ids))
    rows = conn.execute(
        f"""
        SELECT id, path, type, title, summary, date, project, tags
        FROM documents WHERE id IN ({placeholders})
        """,
        doc_ids,
    ).fetchall()
    result = {}
    for r in rows:
        tags = r[7]
        try:
            tags = json.loads(tags) if tags else []
        except (json.JSONDecodeError, TypeError):
            tags = []
        result[r[0]] = {
            "path": r[1],
            "type": r[2],
            "title": r[3],
            "summary": r[4] or "",
            "date": r[5] or "",
            "project": r[6],
            "tags": tags,
        }
    return result


def hybrid_search(
    conn: sqlite3.Connection,
    query: str,
    embedding_model,
    top_k: int = 5,
    type_filter: str | None = None,
    project_filter: str | None = None,
) -> list[SearchResult]:
    """Execute hybrid BM25 + vector search with RRF fusion."""
    fetch_limit = top_k * 3

    # BM25
    bm25_hits = _bm25_search(conn, query, fetch_limit)
    bm25_ranking = [doc_id for doc_id, _, _ in bm25_hits]
    bm25_snippets = {doc_id: snip for doc_id, _, snip in bm25_hits}

    # Vector
    query_vec = list(embedding_model.embed([query]))[0]
    vec_hits = _vector_search(conn, query_vec, fetch_limit)
    vec_ranking = [doc_id for doc_id, _, _ in vec_hits]
    vec_snippets = {doc_id: text for doc_id, _, text in vec_hits}

    # RRF fusion
    rrf_scores = _rrf_fuse(bm25_ranking, vec_ranking)
    if not rrf_scores:
        return []

    # Load metadata
    all_doc_ids = list(rrf_scores.keys())
    metadata = _load_doc_metadata(conn, all_doc_ids)

    # Build results with filtering
    results = []
    for doc_id, score in sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True):
        meta = metadata.get(doc_id)
        if not meta:
            continue
        if type_filter and meta["type"] != type_filter:
            continue
        if project_filter and (
            not meta["project"] or project_filter.lower() not in meta["project"].lower()
        ):
            continue

        # Prefer vector snippet (chunk-level), fallback to BM25 snippet
        snippet = vec_snippets.get(doc_id, bm25_snippets.get(doc_id, ""))
        if len(snippet) > 200:
            snippet = snippet[:200] + "..."

        results.append(
            SearchResult(
                path=meta["path"],
                type=meta["type"],
                title=meta["title"],
                summary=meta["summary"],
                date=meta["date"],
                project=meta["project"],
                tags=meta["tags"],
                score=score,
                snippet=snippet,
            )
        )
        if len(results) >= top_k:
            break

    return results
