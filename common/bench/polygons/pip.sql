-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set limit 100

WITH params AS (
  SELECT ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS pt
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_polygon p, params
WHERE ST_Contains(p.way, params.pt)
LIMIT :limit;
