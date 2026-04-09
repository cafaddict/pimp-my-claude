"""Vault file discovery, parsing, chunking, embedding, and incremental indexing."""

import json
import os
import re
import sqlite3
import struct
import time
from dataclasses import dataclass, field
from pathlib import Path

import frontmatter

TYPE_MAP = {
    "decisions": "decision",
    "lessons": "lesson",
    "sessions": "session",
    "resources": "resource",
    "projects": "project",
    "areas": "area",
    "daily-notes": "daily",
}

SKIP_FILES = {".gitkeep", "CLAUDE.md"}
SKIP_DIRS = {"templates", ".cache", ".obsidian", ".trash", ".smart-env"}


@dataclass
class IndexStats:
    total_files: int = 0
    indexed: int = 0
    skipped: int = 0
    removed: int = 0
    elapsed_sec: float = 0.0


@dataclass
class ParsedFile:
    path: str  # relative to vault root
    type: str
    title: str
    summary: str
    project: str | None
    tags: list[str]
    date: str
    mtime: float
    content: str  # markdown body after frontmatter


def discover_files(vault_dir: str) -> list[tuple[str, float]]:
    """Walk known directories and return (relative_path, mtime) pairs."""
    results = []
    vault = Path(vault_dir)
    for dir_name in TYPE_MAP:
        target = vault / dir_name
        if not target.is_dir():
            continue
        for md_file in target.rglob("*.md"):
            if md_file.name in SKIP_FILES:
                continue
            if any(part in SKIP_DIRS for part in md_file.parts):
                continue
            rel = str(md_file.relative_to(vault))
            results.append((rel, md_file.stat().st_mtime))
    return results


def parse_file(vault_dir: str, rel_path: str, mtime: float) -> ParsedFile:
    """Parse a markdown file with frontmatter."""
    full_path = os.path.join(vault_dir, rel_path)
    post = frontmatter.load(full_path)
    meta = post.metadata
    body = post.content

    top_dir = rel_path.split("/")[0]
    doc_type = TYPE_MAP.get(top_dir, "unknown")

    title_match = re.search(r"^#\s+(.+)", body, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else rel_path

    tags = meta.get("tags", [])
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",")]

    return ParsedFile(
        path=rel_path,
        type=doc_type,
        title=title,
        summary=meta.get("summary", ""),
        project=meta.get("project"),
        tags=tags,
        date=str(meta.get("date", "")),
        mtime=mtime,
        content=body,
    )


def chunk_text(text: str, max_chars: int = 500, overlap: int = 50) -> list[str]:
    """Split text on paragraph boundaries into chunks."""
    paragraphs = re.split(r"\n\n+", text.strip())
    chunks = []
    current = ""

    for para in paragraphs:
        if len(current) + len(para) + 2 > max_chars and current:
            chunks.append(current.strip())
            current = current[-overlap:] + "\n\n" + para if overlap else para
        else:
            current = current + "\n\n" + para if current else para

    if current.strip():
        chunks.append(current.strip())

    return chunks if chunks else [text.strip()]


def serialize_f32(vec) -> bytes:
    """Serialize a float vector to bytes for sqlite-vec."""
    return struct.pack(f"{len(vec)}f", *vec)


def reindex(
    vault_dir: str,
    conn: sqlite3.Connection,
    embedding_model,
    force: bool = False,
) -> IndexStats:
    """Incrementally index vault files into the database."""
    start = time.time()
    stats = IndexStats()

    disk_files = discover_files(vault_dir)
    stats.total_files = len(disk_files)
    disk_paths = {path for path, _ in disk_files}

    # Get existing indexed files
    db_rows = conn.execute("SELECT path, mtime FROM documents").fetchall()
    db_map = {row[0]: row[1] for row in db_rows}

    # Determine what needs updating
    to_process = []
    for rel_path, mtime in disk_files:
        if force or rel_path not in db_map or mtime > db_map[rel_path]:
            to_process.append((rel_path, mtime))
        else:
            stats.skipped += 1

    # Remove deleted files
    to_remove = set(db_map.keys()) - disk_paths
    if to_remove:
        for path in to_remove:
            doc_id = conn.execute(
                "SELECT id FROM documents WHERE path = ?", (path,)
            ).fetchone()
            if doc_id:
                doc_id = doc_id[0]
                conn.execute("DELETE FROM chunks WHERE doc_id = ?", (doc_id,))
                conn.execute("DELETE FROM chunks_vec WHERE doc_id = ?", (doc_id,))
                conn.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
        stats.removed = len(to_remove)

    if not to_process:
        conn.commit()
        stats.elapsed_sec = time.time() - start
        return stats

    # Parse files
    parsed_files = []
    for rel_path, mtime in to_process:
        try:
            parsed_files.append(parse_file(vault_dir, rel_path, mtime))
        except Exception:
            stats.skipped += 1
            continue

    # Chunk all files and collect texts for batch embedding
    all_chunks: list[tuple[int, int, str]] = []  # (file_idx, chunk_idx, text)
    for file_idx, pf in enumerate(parsed_files):
        chunks = chunk_text(pf.content)
        for chunk_idx, text in enumerate(chunks):
            all_chunks.append((file_idx, chunk_idx, text))

    # Batch embed all chunks
    embed_texts = [text for _, _, text in all_chunks]
    embeddings = list(embedding_model.embed(embed_texts)) if embed_texts else []

    # Write to DB
    embed_idx = 0
    for file_idx, pf in enumerate(parsed_files):
        # Upsert document
        existing = conn.execute(
            "SELECT id FROM documents WHERE path = ?", (pf.path,)
        ).fetchone()

        if existing:
            doc_id = existing[0]
            conn.execute(
                """UPDATE documents SET type=?, title=?, summary=?, project=?,
                   tags=?, date=?, mtime=?, content=? WHERE id=?""",
                (
                    pf.type,
                    pf.title,
                    pf.summary,
                    pf.project,
                    json.dumps(pf.tags, ensure_ascii=False),
                    pf.date,
                    pf.mtime,
                    pf.content,
                    doc_id,
                ),
            )
            conn.execute("DELETE FROM chunks WHERE doc_id = ?", (doc_id,))
            conn.execute("DELETE FROM chunks_vec WHERE doc_id = ?", (doc_id,))
        else:
            cursor = conn.execute(
                """INSERT INTO documents (path, type, title, summary, project, tags, date, mtime, content)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    pf.path,
                    pf.type,
                    pf.title,
                    pf.summary,
                    pf.project,
                    json.dumps(pf.tags, ensure_ascii=False),
                    pf.date,
                    pf.mtime,
                    pf.content,
                ),
            )
            doc_id = cursor.lastrowid

        # Insert chunks for this file
        file_chunks = [c for c in all_chunks if c[0] == file_idx]
        for _, chunk_idx, text in file_chunks:
            conn.execute(
                "INSERT INTO chunks (doc_id, chunk_idx, text) VALUES (?, ?, ?)",
                (doc_id, chunk_idx, text),
            )
            vec_rowid = conn.execute(
                "SELECT COALESCE(MAX(rowid), 0) + 1 FROM chunks_vec"
            ).fetchone()[0]
            conn.execute(
                "INSERT INTO chunks_vec (rowid, embedding, doc_id, chunk_idx) VALUES (?, ?, ?, ?)",
                (vec_rowid, serialize_f32(embeddings[embed_idx]), doc_id, chunk_idx),
            )
            embed_idx += 1

        stats.indexed += 1

    conn.commit()
    stats.elapsed_sec = time.time() - start
    return stats
