"""Database schema and connection helper for vault search."""

import os
import sqlite3

import sqlite_vec


def init_db(db_path: str) -> sqlite3.Connection:
    """Initialize the database with schema and return a connection."""
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    sqlite_vec.load(conn)
    _create_tables(conn)
    return conn


def _create_tables(conn: sqlite3.Connection) -> None:
    conn.executescript("""
        -- Documents: one row per markdown file
        CREATE TABLE IF NOT EXISTS documents (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            path    TEXT NOT NULL UNIQUE,
            type    TEXT NOT NULL,
            title   TEXT,
            summary TEXT,
            project TEXT,
            tags    TEXT,
            date    TEXT,
            mtime   REAL NOT NULL,
            content TEXT NOT NULL
        );

        -- FTS5 for BM25 keyword search
        CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
            title,
            summary,
            content,
            tags,
            content=documents,
            content_rowid=id,
            tokenize='unicode61'
        );

        -- Keep FTS in sync with documents table
        CREATE TRIGGER IF NOT EXISTS documents_ai AFTER INSERT ON documents BEGIN
            INSERT INTO documents_fts(rowid, title, summary, content, tags)
            VALUES (new.id, new.title, new.summary, new.content, new.tags);
        END;

        CREATE TRIGGER IF NOT EXISTS documents_ad AFTER DELETE ON documents BEGIN
            INSERT INTO documents_fts(documents_fts, rowid, title, summary, content, tags)
            VALUES ('delete', old.id, old.title, old.summary, old.content, old.tags);
        END;

        CREATE TRIGGER IF NOT EXISTS documents_au AFTER UPDATE ON documents BEGIN
            INSERT INTO documents_fts(documents_fts, rowid, title, summary, content, tags)
            VALUES ('delete', old.id, old.title, old.summary, old.content, old.tags);
            INSERT INTO documents_fts(rowid, title, summary, content, tags)
            VALUES (new.id, new.title, new.summary, new.content, new.tags);
        END;

        -- Chunk text metadata
        CREATE TABLE IF NOT EXISTS chunks (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            doc_id    INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
            chunk_idx INTEGER NOT NULL,
            text      TEXT NOT NULL,
            UNIQUE(doc_id, chunk_idx)
        );
    """)

    # sqlite-vec virtual table (cannot be inside executescript)
    tables = {
        r[0]
        for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    }
    if "chunks_vec" not in tables:
        conn.execute("""
            CREATE VIRTUAL TABLE chunks_vec USING vec0(
                embedding float[384],
                +doc_id   INTEGER,
                +chunk_idx INTEGER
            )
        """)

    conn.commit()
