-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set radius_m 1000\n--   \set limit 100

WITH params AS (
  SELECT
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center,
    :radius_m::double precision AS radius_m
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p, params
WHERE ST_DWithin(p.way::geography, params.center::geography, params.radius_m)
LIMIT :limit;
