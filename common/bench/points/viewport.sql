-- Variables (psql):\n--   \set minx 139.77\n--   \set miny 35.71\n--   \set maxx 139.79\n--   \set maxy 35.73\n--   \set limit 100

WITH bbox AS (
  SELECT ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom
)
SELECT
  osm_id,
  way,
  name
FROM planet_osm_point, bbox
WHERE way && bbox.geom
  AND ST_Intersects(way, bbox.geom)
LIMIT :limit;
