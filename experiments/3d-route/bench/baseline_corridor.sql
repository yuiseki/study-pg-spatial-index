-- baseline_corridor: PostGIS GiST + numeric height range filter.
--
-- Strategy:
--   1. corridor bbox && geom  → GiST candidate scan
--   2. ST_Intersects recheck  → eliminates bbox FP
--   3. max_height_m >= height_min AND min_height_m <= height_max → numeric filter
--
-- Variables (psql):
--   \set altitude_m   30
--   \set clearance_m  5

-- altitude_m and clearance_m must be passed via psql -v (no \set defaults here)

WITH corridor AS (
  SELECT geom, height_min_m, height_max_m
  FROM route_corridor
  WHERE altitude_m = :altitude_m AND clearance_m = :clearance_m
  LIMIT 1
)
SELECT
  b.osm_id,
  b.max_height_m,
  b.min_height_m,
  b.height_source
FROM corridor c
JOIN building_height_model b
  ON b.geom && c.geom
 AND ST_Intersects(b.geom, c.geom)
 AND b.max_height_m >= c.height_min_m
 AND b.min_height_m <= c.height_max_m
ORDER BY b.osm_id;
