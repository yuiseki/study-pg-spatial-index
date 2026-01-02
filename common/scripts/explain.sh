#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: explain.sh <query.sql> <out.txt> [var=value ...]" >&2
  exit 2
fi

query_file=$1
out_file=$2
shift 2

pg_host=${PGHOST:-localhost}
pg_port=${PGPORT:-5432}
pg_db=${PGDATABASE:-postgres}
pg_user=${PGUSER:-postgres}
pg_password=${PGPASSWORD:-postgres}

vars=()
for kv in "$@"; do
  vars+=("-v" "$kv")
done

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

{
  echo "\\set ON_ERROR_STOP on"
  echo "EXPLAIN (ANALYZE, BUFFERS)"
  cat "$query_file"
} > "$tmp_file"

PGPASSWORD="$pg_password" psql \
  --host "$pg_host" \
  --port "$pg_port" \
  --username "$pg_user" \
  --dbname "$pg_db" \
  "${vars[@]}" \
  --file "$tmp_file" \
  > "$out_file"
