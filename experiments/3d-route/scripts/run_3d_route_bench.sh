#!/usr/bin/env bash
# run_3d_route_bench.sh — sets up 3D route tables and runs corridor benchmarks.
#
# Target: zfxy container (has PostGIS + zfxy functions)
# Default port: 55442  (override with PGPORT=xxxx)
#
# Usage:
#   experiments/3d-route/scripts/run_3d_route_bench.sh
#   PGPORT=55442 experiments/3d-route/scripts/run_3d_route_bench.sh
set -euo pipefail

PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-55442}
PGDATABASE=${PGDATABASE:-postgres}
PGUSER=${PGUSER:-postgres}
PGPASSWORD=${PGPASSWORD:-postgres}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

export PGPASSWORD

_psql() {
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" "$@"
}

stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
out_dir="${REPO_ROOT}/results/3d-route/${stamp}"
mkdir -p "${out_dir}/explain" "${out_dir}/sql"

echo "=== 3D Route Bench: ${stamp} ==="
echo "Target: ${PGHOST}:${PGPORT}/${PGDATABASE}"
echo "Output: ${out_dir}"

# -----------------------------------------------------------------------
# 1. Setup SQL
# -----------------------------------------------------------------------
echo ""
echo "--- Setup ---"
for sql_file in \
    "${REPO_ROOT}/experiments/3d-route/sql/10_parse_height.sql" \
    "${REPO_ROOT}/experiments/3d-route/sql/20_building_height_model.sql" \
    "${REPO_ROOT}/experiments/3d-route/sql/30_route_corridor.sql" \
    "${REPO_ROOT}/experiments/3d-route/sql/40_zfxy_3d_cells.sql" \
    "${REPO_ROOT}/experiments/3d-route/sql/50_baseline_indexes.sql"
do
    echo "  Running $(basename "${sql_file}")..."
    cp "${sql_file}" "${out_dir}/sql/$(basename "${sql_file}")"
    _psql -f "${sql_file}" 2>&1 | grep -v "^$" || true
done

# -----------------------------------------------------------------------
# 2. Collect metadata
# -----------------------------------------------------------------------
echo ""
echo "--- Metadata ---"

building_count=$(_psql -t -c "SELECT COUNT(*) FROM building_height_model;" | tr -d ' ')
point_count=$(_psql -t -c "SELECT COUNT(*) FROM planet_osm_point;" | tr -d ' ')
polygon_count=$(_psql -t -c "SELECT COUNT(*) FROM planet_osm_polygon;" | tr -d ' ')
cells_2d=$(_psql -t -c "SELECT COUNT(*) FROM planet_osm_polygon_zfxy WHERE resolution=15;" | tr -d ' ')
cells_3d_total=$(_psql -t -c "SELECT COUNT(*) FROM planet_osm_building_zfxy_3d WHERE resolution=19;" | tr -d ' ')
cells_3d_f0=$(_psql -t -c "SELECT COUNT(*) FROM planet_osm_building_zfxy_3d WHERE resolution=19 AND f=0;" | tr -d ' ')
skipped=$(_psql -t -c "SELECT COUNT(*) FROM building_zfxy_3d_skipped WHERE resolution=19;" | tr -d ' ')

cat > "${out_dir}/metadata.json" <<EOF
{
  "timestamp": "${stamp}",
  "dataset": "OSM Taito-ku",
  "point_count": ${point_count},
  "polygon_count": ${polygon_count},
  "building_count": ${building_count},
  "height_model": "parse_height_m + building:levels*3 + default_15m",
  "unknown_height_policy": "default_15m",
  "zfxy_3d_resolution": 19,
  "cells_2d_z15": ${cells_2d},
  "cells_3d_z19_total": ${cells_3d_total},
  "cells_3d_z19_f_eq_0": ${cells_3d_f0},
  "cells_3d_z19_f_gt_0": $((cells_3d_total - cells_3d_f0)),
  "buildings_skipped_cap": ${skipped},
  "corridor": {
    "center_lon": 139.785,
    "south_lat": 35.695,
    "north_lat": 35.731,
    "width_m": 100,
    "minx": 139.784450,
    "maxx": 139.785550
  },
  "altitude_levels_m": [30, 60, 90, 120],
  "clearance_m": 5,
  "jit": "off",
  "cache": "warm"
}
EOF
echo "  metadata.json written."

# -----------------------------------------------------------------------
# 3. Index sizes
# -----------------------------------------------------------------------
echo ""
echo "--- Index sizes ---"
_psql -c "
SELECT
  c.relname            AS object_name,
  pg_size_pretty(pg_relation_size(c.oid))        AS data_size,
  pg_size_pretty(pg_indexes_size(c.oid))         AS indexes_size,
  pg_size_pretty(pg_total_relation_size(c.oid))  AS total_size
FROM pg_class c
WHERE c.relname IN (
  'building_height_model',
  'planet_osm_building_zfxy_3d',
  'planet_osm_polygon_zfxy',
  'planet_osm_polygon'
)
ORDER BY pg_total_relation_size(c.oid) DESC;
" | tee "${out_dir}/index_sizes.txt"

# -----------------------------------------------------------------------
# 4. F-granularity analysis
# -----------------------------------------------------------------------
echo ""
echo "--- zfxy f-granularity at z=17,18,19 ---"
_psql -c "
SELECT
  z,
  round(power(2,25)::numeric / power(2,z)::numeric, 1) AS meters_per_f_unit,
  floor(30.0  * power(2,z) / power(2,25)) AS f_30m,
  floor(60.0  * power(2,z) / power(2,25)) AS f_60m,
  floor(90.0  * power(2,z) / power(2,25)) AS f_90m,
  floor(130.0 * power(2,z) / power(2,25)) AS f_130m
FROM generate_series(17, 22) AS z;
" | tee "${out_dir}/f_granularity.txt"

echo ""
echo "--- 3D cell distribution (z=19) ---"
_psql -c "
SELECT
  f,
  COUNT(DISTINCT osm_id) AS buildings,
  COUNT(*)               AS cells
FROM planet_osm_building_zfxy_3d
WHERE resolution = 19
GROUP BY f ORDER BY f;
" | tee "${out_dir}/cell_distribution_z19.txt"

# -----------------------------------------------------------------------
# 5. Warm-up pass (results discarded)
# -----------------------------------------------------------------------
echo ""
echo "--- Warm-up ---"
_psql -v altitude_m=30 -v clearance_m=5 \
    -c "SET jit=off;" \
    -f "${REPO_ROOT}/experiments/3d-route/bench/baseline_corridor.sql" > /dev/null 2>&1 || true
_psql -v altitude_m=30 -v clearance_m=5 -v resolution=19 \
    -c "SET jit=off;" \
    -f "${REPO_ROOT}/experiments/3d-route/bench/zfxy_corridor.sql" > /dev/null 2>&1 || true
echo "  Done."

# -----------------------------------------------------------------------
# 6. EXPLAIN ANALYZE at each altitude level
# -----------------------------------------------------------------------
echo ""
echo "--- EXPLAIN ANALYZE ---"

run_explain() {
    local bench_file=$1   # full filename without .sql, e.g. "baseline_corridor"
    local altitude=$2
    local extra_vars=$3
    local out="${out_dir}/explain/${bench_file}_alt${altitude}m.txt"
    echo "  ${bench_file} alt=${altitude}m..."

    tmp=$(mktemp)
    trap 'rm -f "$tmp"' RETURN
    {
        printf '\\set ON_ERROR_STOP on\n'
        printf 'SET jit = off;\n'
        printf 'EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)\n'
        cat "${REPO_ROOT}/experiments/3d-route/bench/${bench_file}.sql"
    } > "$tmp"

    PGPASSWORD="$PGPASSWORD" psql \
        -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
        -v altitude_m="$altitude" -v clearance_m=5 \
        ${extra_vars} \
        -f "$tmp" > "$out" 2>&1
}

for altitude in 30 60 90 120; do
    run_explain baseline_corridor "$altitude" ""
    run_explain zfxy_corridor     "$altitude" "-v resolution=19"
done

# -----------------------------------------------------------------------
# 7. Candidate / actual count per altitude
# -----------------------------------------------------------------------
echo ""
echo "--- Candidate / actual counts ---"

_psql -c "
SET jit = off;
WITH results AS (
  SELECT
    rc.altitude_m,
    rc.height_min_m,
    rc.height_max_m,
    -- baseline candidates (bbox only, no ST_Intersects, no height filter)
    (SELECT COUNT(*) FROM building_height_model b
     WHERE b.geom && rc.geom)                                          AS baseline_bbox_cands,
    -- baseline actual (with ST_Intersects + height filter)
    (SELECT COUNT(*) FROM building_height_model b
     WHERE b.geom && rc.geom
       AND ST_Intersects(b.geom, rc.geom)
       AND b.max_height_m >= rc.height_min_m
       AND b.min_height_m <= rc.height_max_m)                          AS baseline_actual,
    -- zfxy_3d f range
    zfxy_f(rc.altitude_m - rc.clearance_m, 19) AS f_min,
    zfxy_f(rc.altitude_m + rc.clearance_m, 19) AS f_max,
    -- zfxy_3d candidates (cell scan only, no recheck)
    (SELECT COUNT(DISTINCT z.osm_id)
     FROM planet_osm_building_zfxy_3d z
     WHERE z.resolution = 19
       AND z.f BETWEEN zfxy_f(rc.altitude_m - rc.clearance_m, 19)
                   AND zfxy_f(rc.altitude_m + rc.clearance_m, 19)
       AND z.x BETWEEN zfxy_x(rc.corridor_minx, 19) AND zfxy_x(rc.corridor_maxx, 19)
       AND z.y BETWEEN zfxy_y(rc.corridor_maxy, 19) AND zfxy_y(rc.corridor_miny, 19))
                                                                       AS zfxy_cell_cands
  FROM route_corridor rc
)
SELECT
  altitude_m,
  height_min_m,
  height_max_m,
  f_min,
  f_max,
  baseline_bbox_cands,
  baseline_actual,
  round((baseline_bbox_cands - baseline_actual)::numeric
        / NULLIF(baseline_bbox_cands, 0) * 100, 1) AS baseline_fp_pct,
  zfxy_cell_cands,
  round((zfxy_cell_cands - baseline_actual)::numeric
        / NULLIF(zfxy_cell_cands, 0) * 100, 1)     AS zfxy_fp_pct
FROM results
ORDER BY altitude_m;
" | tee "${out_dir}/candidate_counts.txt"

# -----------------------------------------------------------------------
# 8. Summary CSV (execution times from EXPLAIN output)
# -----------------------------------------------------------------------
echo ""
echo "--- Extracting execution times ---"
python3 "${SCRIPT_DIR}/summarize_results.py" "${out_dir}" | tee "${out_dir}/summary.md"

echo ""
echo "=== Done: ${out_dir} ==="
