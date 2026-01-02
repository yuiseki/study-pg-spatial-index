#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: run_bench.sh <system-name>" >&2
  exit 2
fi

system=$1

pg_port=${PGPORT:-5432}
pg_host=${PGHOST:-localhost}
pg_db=${PGDATABASE:-postgres}
pg_user=${PGUSER:-postgres}
pg_password=${PGPASSWORD:-postgres}

# Default AOI around Taito-ku (can be overridden via env)
minx=${MINX:-139.77}
miny=${MINY:-35.71}
maxx=${MAXX:-139.79}
maxy=${MAXY:-35.73}
lon=${LON:-139.777}
lat=${LAT:-35.713}
radius_m=${RADIUS_M:-1000}
limit=${LIMIT:-100}

stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
out_dir="results/${system}/${stamp}/explain"
mkdir -p "$out_dir"

run_explain() {
  local query=$1
  local out=$2
  shift 2
  PGPASSWORD="$pg_password" PGHOST="$pg_host" PGPORT="$pg_port" PGDATABASE="$pg_db" PGUSER="$pg_user" \
    common/scripts/explain.sh "$query" "$out" "$@"
}

resolve_query() {
  local rel=$1
  local system_query="systems/${system}/bench/${rel}"
  local common_query="common/bench/${rel}"
  if [[ -f "$system_query" ]]; then
    echo "$system_query"
  else
    echo "$common_query"
  fi
}

run_explain "$(resolve_query points/viewport.sql)" "$out_dir/points_viewport.txt" \
  minx="$minx" miny="$miny" maxx="$maxx" maxy="$maxy" limit="$limit"

run_explain "$(resolve_query points/radius.sql)" "$out_dir/points_radius.txt" \
  lon="$lon" lat="$lat" radius_m="$radius_m" limit="$limit"

run_explain "$(resolve_query points/knn.sql)" "$out_dir/points_knn.txt" \
  lon="$lon" lat="$lat" limit="$limit"

run_explain "$(resolve_query polygons/viewport.sql)" "$out_dir/polygons_viewport.txt" \
  minx="$minx" miny="$miny" maxx="$maxx" maxy="$maxy" limit="$limit"

run_explain "$(resolve_query polygons/pip.sql)" "$out_dir/polygons_pip.txt" \
  lon="$lon" lat="$lat" limit="$limit"

echo "$out_dir"
