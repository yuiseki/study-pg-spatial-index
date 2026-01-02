-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set radius_m 1000
--   \set limit 100

WITH params AS (
  SELECT
    :lon::double precision AS lon,
    :lat::double precision AS lat,
    (:radius_m::double precision / 111320.0) AS radius_deg
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_q3c q
  ON p.osm_id = q.osm_id
JOIN params ON true
WHERE q3c_radial_query(q.lon, q.lat, params.lon, params.lat, params.radius_deg)
ORDER BY q3c_dist(q.lon, q.lat, params.lon, params.lat)
LIMIT :limit;
