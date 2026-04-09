"""MCP server for Obsidian vault hybrid semantic search."""

import json
import os
import sqlite3
import sys

from mcp.server.fastmcp import FastMCP

from db import init_db
from indexer import reindex, IndexStats
from searcher import hybrid_search

mcp = FastMCP(name="vault-search")

# Lazy singletons
_conn: sqlite3.Connection | None = None
_model = None
_vault_dir: str | None = None


def _get_vault_dir() -> str:
    global _vault_dir
    if _vault_dir is None:
        _vault_dir = os.environ.get(
            "CLAUDE_VAULT_DIR", os.path.expanduser("~/Documents/vault")
        )
    return _vault_dir


def _get_connection() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        vault_dir = _get_vault_dir()
        db_path = os.path.join(vault_dir, ".cache", "vault-search.db")
        _conn = init_db(db_path)
    return _conn


def _get_embedding_model():
    global _model
    if _model is None:
        from fastembed import TextEmbedding

        _model = TextEmbedding(
            model_name="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
        )
    return _model


def _auto_incremental_index(conn: sqlite3.Connection) -> IndexStats | None:
    """Run incremental indexing if any files changed since last index."""
    vault_dir = _get_vault_dir()
    model = _get_embedding_model()
    stats = reindex(vault_dir, conn, model, force=False)
    if stats.indexed > 0 or stats.removed > 0:
        return stats
    return None


@mcp.tool()
def search(
    query: str,
    top_k: int = 5,
    type_filter: str | None = None,
    project_filter: str | None = None,
) -> str:
    """Search the Obsidian vault using hybrid BM25 + semantic search.

    Args:
        query: Search query (Korean or English)
        top_k: Number of results to return (default 5, max 20)
        type_filter: Filter by note type: decision, lesson, session, resource, project, area, daily
        project_filter: Filter by project name (matches frontmatter 'project' field)

    Returns:
        JSON array of search results with path, title, summary, date, type, project, tags, score, snippet
    """
    top_k = min(max(top_k, 1), 20)
    conn = _get_connection()

    # Auto-index any changed files before searching
    _auto_incremental_index(conn)

    model = _get_embedding_model()
    results = hybrid_search(conn, query, model, top_k, type_filter, project_filter)

    return json.dumps(
        [
            {
                "path": r.path,
                "type": r.type,
                "title": r.title,
                "summary": r.summary,
                "date": r.date,
                "project": r.project,
                "tags": r.tags,
                "score": round(r.score, 4),
                "snippet": r.snippet,
            }
            for r in results
        ],
        ensure_ascii=False,
        indent=2,
    )


@mcp.tool()
def reindex_vault(force: bool = False) -> str:
    """Rebuild the vault search index. Only re-indexes files modified since last index.

    Args:
        force: If True, re-index all files regardless of modification time

    Returns:
        JSON object with indexing statistics
    """
    conn = _get_connection()
    vault_dir = _get_vault_dir()
    model = _get_embedding_model()
    stats = reindex(vault_dir, conn, model, force=force)

    return json.dumps(
        {
            "total_files": stats.total_files,
            "indexed": stats.indexed,
            "skipped": stats.skipped,
            "removed": stats.removed,
            "elapsed_sec": round(stats.elapsed_sec, 2),
        }
    )


if __name__ == "__main__":
    mcp.run(transport="stdio")
