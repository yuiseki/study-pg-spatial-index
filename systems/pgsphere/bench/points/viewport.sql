-- Variables (psql):
--   \set minx 139.77
--   \set miny 35.71
--   \set maxx 139.79
--   \set maxy 35.73
--   \set limit 100

WITH params AS (
  SELECT spoly_deg(ARRAY[
    :minx, :miny,
    :maxx, :miny,
    :maxx, :maxy,
    :minx, :maxy
  ]) AS poly
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_pgsphere s
  ON p.osm_id = s.osm_id
JOIN params ON true
WHERE s.spoint <@ params.poly
LIMIT :limit;
