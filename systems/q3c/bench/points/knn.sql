-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set limit 100

WITH params AS (
  SELECT
    :lon::double precision AS lon,
    :lat::double precision AS lat
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_q3c q
  ON p.osm_id = q.osm_id
JOIN params ON true
ORDER BY q3c_dist(q.lon, q.lat, params.lon, params.lat)
LIMIT :limit;
