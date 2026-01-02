-- Variables (psql):
--   \set minx 139.77
--   \set miny 35.71
--   \set maxx 139.79
--   \set maxy 35.73
--   \set limit 100

WITH params AS (
  SELECT ARRAY[
    :minx, :miny,
    :maxx, :miny,
    :maxx, :maxy,
    :minx, :maxy
  ]::double precision[] AS poly
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_q3c q
  ON p.osm_id = q.osm_id
JOIN params ON true
WHERE q3c_poly_query(q.lon, q.lat, params.poly)
LIMIT :limit;
