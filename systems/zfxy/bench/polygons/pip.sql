-- zfxy: Polygons — Point-in-Polygon
--
-- Strategy:
--   1. Compute the tile containing the query point.
--   2. Find polygons whose cover table includes that tile (B-tree lookup).
--   3. Recheck with ST_Contains.
--
-- Because the polygon cover is a bbox cover (not a strict poly cover),
-- false positives are possible at step 2; ST_Contains eliminates them.
--
-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set limit 10
--   \set resolution 15

\set resolution 15

WITH params AS (
  SELECT
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)      AS pt
),
point_cell AS (
  SELECT
    zfxy_x(:lon::double precision, :resolution)     AS px,
    zfxy_y(:lat::double precision, :resolution)     AS py
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_polygon p
JOIN planet_osm_polygon_zfxy z
  ON p.osm_id = z.osm_id
 AND z.resolution = :resolution
JOIN point_cell pc ON z.x = pc.px AND z.y = pc.py
WHERE ST_Contains(p.way, (SELECT pt FROM params))
LIMIT :limit;
