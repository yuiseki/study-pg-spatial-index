-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set limit 100\n--   \set resolution 9\n--   \set k 6

\set resolution 9
\set k 6

WITH params AS (
  SELECT ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center
),
origin AS (
  SELECT h3_latlng_to_cell(point(:lon, :lat), :resolution) AS cell
),
cell_candidates AS (
  SELECT h3_cell
  FROM origin,
       LATERAL h3_grid_disk(origin.cell, :k) AS h3_cell(h3_cell)
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_h3 h
  ON p.osm_id = h.osm_id
 AND h.resolution = :resolution
JOIN cell_candidates c
  ON h.h3_cell = c.h3_cell
ORDER BY p.way <-> (SELECT center FROM params)
LIMIT :limit;
