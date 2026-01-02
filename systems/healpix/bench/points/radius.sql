-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set radius_m 1000\n--   \set limit 100\n--   \set nside 1024

\set nside 1024

WITH params AS (
  SELECT
    :lon::double precision AS lon,
    :lat::double precision AS lat,
    :radius_m::double precision AS radius_m,
    (:radius_m::double precision / 111320.0) AS radius_deg
),
bbox AS (
  SELECT
    lon - radius_deg AS minx,
    lat - radius_deg AS miny,
    lon + radius_deg AS maxx,
    lat + radius_deg AS maxy,
    ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS center,
    radius_m
  FROM params
),
ipix AS (
  SELECT
    LEAST(
      healpix_ang2ipix_nest(:nside, minx, miny),
      healpix_ang2ipix_nest(:nside, maxx, miny),
      healpix_ang2ipix_nest(:nside, maxx, maxy),
      healpix_ang2ipix_nest(:nside, minx, maxy)
    ) AS ipix_min,
    GREATEST(
      healpix_ang2ipix_nest(:nside, minx, miny),
      healpix_ang2ipix_nest(:nside, maxx, miny),
      healpix_ang2ipix_nest(:nside, maxx, maxy),
      healpix_ang2ipix_nest(:nside, minx, maxy)
    ) AS ipix_max
  FROM bbox
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_healpix h
  ON p.osm_id = h.osm_id
JOIN bbox ON true
JOIN ipix ON true
WHERE h.ipix BETWEEN ipix.ipix_min AND ipix.ipix_max
  AND ST_DWithin(p.way::geography, bbox.center::geography, bbox.radius_m)
LIMIT :limit;
