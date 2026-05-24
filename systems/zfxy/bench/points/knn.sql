-- zfxy: Points — kNN (approximate, bbox expansion + PostGIS recheck)
--
-- Strategy:
--   1. Find the tile containing the query point.
--   2. Expand outward by ±expand tiles in both x and y directions.
--   3. Candidate extraction via B-tree range scan on (resolution, x, y).
--   4. Order by PostGIS <-> distance operator; take LIMIT.
--
-- IMPORTANT: This is NOT equivalent to H3 h3_grid_disk ring expansion or
-- PostGIS <-> index-accelerated kNN.
--   - The tile-range expansion is square (not hexagonal / spherical).
--   - If fewer than :limit candidates fall within the expanded range, results
--     will be incomplete.  Increase :expand to widen the search at the cost
--     of more candidates.
--   - PostGIS GiST <-> directly uses an R-tree walk and is typically faster
--     for strict kNN; this approach trades index type for observability.
--
-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set limit 20
--   \set resolution 15
--   \set expand 2

\set resolution 15
\set expand 2

WITH params AS (
  SELECT
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center
),
origin AS (
  SELECT
    zfxy_x(:lon::double precision, :resolution) AS ox,
    zfxy_y(:lat::double precision, :resolution) AS oy
),
tile_range AS (
  SELECT
    ox - :expand AS x_min,
    ox + :expand AS x_max,
    oy - :expand AS y_min,
    oy + :expand AS y_max
  FROM origin
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_zfxy z
  ON p.osm_id = z.osm_id
 AND z.resolution = :resolution
JOIN tile_range tr ON true
WHERE z.x BETWEEN tr.x_min AND tr.x_max
  AND z.y BETWEEN tr.y_min AND tr.y_max
ORDER BY p.way <-> (SELECT center FROM params)
LIMIT :limit;
