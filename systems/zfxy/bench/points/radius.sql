-- zfxy: Points — Radius search
--
-- Strategy:
--   1. Derive a bbox from the circle (center ± radius_deg).
--   2. Compute tile (x, y) range covering that bbox.
--   3. Candidate extraction via B-tree range scan on (resolution, x, y).
--   4. Recheck with ST_DWithin(geography) for the exact circle.
--
-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set radius_m 1000
--   \set limit 100
--   \set resolution 15

\set resolution 15

WITH params AS (
  SELECT
    :lon::double precision                                   AS lon,
    :lat::double precision                                   AS lat,
    :radius_m::double precision                              AS radius_m,
    (:radius_m::double precision / 111320.0)                 AS radius_deg,
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)               AS center
),
bbox AS (
  SELECT
    lon - radius_deg AS minx,
    lat - radius_deg AS miny,
    lon + radius_deg AS maxx,
    lat + radius_deg AS maxy,
    center,
    radius_m
  FROM params
),
tile_range AS (
  SELECT
    zfxy_x(minx, :resolution) AS x_min,
    zfxy_x(maxx, :resolution) AS x_max,
    zfxy_y(maxy, :resolution) AS y_min,
    zfxy_y(miny, :resolution) AS y_max
  FROM bbox
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_zfxy z
  ON p.osm_id = z.osm_id
 AND z.resolution = :resolution
JOIN tile_range  tr ON true
JOIN bbox        b  ON true
WHERE z.x BETWEEN tr.x_min AND tr.x_max
  AND z.y BETWEEN tr.y_min AND tr.y_max
  AND ST_DWithin(p.way::geography, b.center::geography, b.radius_m)
LIMIT :limit;
