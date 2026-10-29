#!/bin/bash
# CS 511 Project 2, Part 2: build the index and start the search API on main.
#
#   bash serve.sh <articles_uri> <ranks_uri>
#
# `make serve` and the tests copy this directory to /search on main and run
# this script there (so hdfs, spark-submit and python3 are at hand). It must
# (re)build everything from the given inputs, start the server in the
# background on port 8000, and return once GET /health answers. Run it twice
# and the second run must replace the first server.
set -eo pipefail
cd "$(dirname "$0")"

ARTICLES_URI="$1"
RANKS_URI="$2"
INDEX_URI="hdfs://main:9000/search/index"
DATABASE=/data/search.db

# 0. Stop a server started earlier.
pkill -f '[s]erver.py' || true

# 1. Build the index with Spark.
hdfs dfs -rm -r -f "$INDEX_URI"
spark-submit --master spark://main:7077 indexer.py "$ARTICLES_URI" "$RANKS_URI" "$INDEX_URI"

# 2. Load it into SQLite (a fresh file every time).
mkdir -p "$(dirname "$DATABASE")"
rm -f "$DATABASE"
START=$SECONDS
hdfs dfs -cat "${INDEX_URI}/docs/part-*" | python3 load_index.py "$DATABASE" docs
hdfs dfs -cat "${INDEX_URI}/postings/part-*" | python3 load_index.py "$DATABASE" postings
echo "DATABASE LOAD SECONDS: $((SECONDS - START))"
ls -l "$DATABASE"

# 3. Start the server in the background and wait until it answers.
setsid nohup python3 server.py --port 8000 --database "$DATABASE" > /search/server.log 2>&1 < /dev/null &
for _ in $(seq 1 120); do
    if python3 -c 'import urllib.request; urllib.request.urlopen("http://localhost:8000/health", timeout=2)' \
            2>/dev/null; then
        echo "search API ready on port 8000"
        exit 0
    fi
    sleep 1
done
echo "the server did not start; see /search/server.log" >&2
exit 1
