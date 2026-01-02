-- Variables (psql):
--   \set lon 139.777
--   \set lat 35.713
--   \set radius_m 1000
--   \set limit 100

WITH params AS (
  SELECT
    spoint_deg(:lon, :lat) AS center,
    (:radius_m::double precision / 111320.0) AS radius_deg
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_pgsphere s
  ON p.osm_id = s.osm_id
JOIN params ON true
WHERE s.spoint <@ scircle_deg(params.center, params.radius_deg)
LIMIT :limit;
