#!/usr/bin/env python3
"""Load the Spark index (read from stdin or files) into a SQLite database.

    python3 load_index.py <db_path> docs   < docs lines
    python3 load_index.py <db_path> postings < postings lines
"""
import sqlite3
import sys

BATCH = 50000


def main(argv):
    db_path, kind = argv[1], argv[2]
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("PRAGMA cache_size=-200000")
    if kind == "docs":
        conn.execute("CREATE TABLE IF NOT EXISTS docs "
                     "(id INTEGER PRIMARY KEY, rank REAL NOT NULL, title TEXT NOT NULL)")
        rows = []
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            doc_id, rank, title = line.split("\t", 2)
            rows.append((int(doc_id), float(rank), title))
            if len(rows) >= BATCH:
                conn.executemany("INSERT INTO docs VALUES (?,?,?)", rows)
                rows = []
        if rows:
            conn.executemany("INSERT INTO docs VALUES (?,?,?)", rows)
    else:
        conn.execute("CREATE TABLE IF NOT EXISTS postings "
                     "(term TEXT NOT NULL, doc_id INTEGER NOT NULL, weight REAL NOT NULL, "
                     "PRIMARY KEY (term, doc_id)) WITHOUT ROWID")
        rows = []
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            term, entries = line.split("\t", 1)
            for entry in entries.split(","):
                doc_id, weight = entry.split(":")
                rows.append((term, int(doc_id), float(weight)))
            if len(rows) >= BATCH:
                conn.executemany("INSERT INTO postings VALUES (?,?,?)", rows)
                rows = []
        if rows:
            conn.executemany("INSERT INTO postings VALUES (?,?,?)", rows)
    conn.commit()
    conn.close()


if __name__ == "__main__":
    main(sys.argv)
