-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set limit 100\n--   \set nside 1024\n--   \set bbox_deg 0.01

\set nside 1024
\set bbox_deg 0.01

WITH params AS (
  SELECT
    :lon::double precision AS lon,
    :lat::double precision AS lat,
    :bbox_deg::double precision AS bbox_deg,
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center
),
bbox AS (
  SELECT
    lon - bbox_deg AS minx,
    lat - bbox_deg AS miny,
    lon + bbox_deg AS maxx,
    lat + bbox_deg AS maxy,
    center
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
ORDER BY p.way <-> bbox.center
LIMIT :limit;
