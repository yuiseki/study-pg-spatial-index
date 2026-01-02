-- Variables (psql):\n--   \set minx 139.77\n--   \set miny 35.71\n--   \set maxx 139.79\n--   \set maxy 35.73\n--   \set limit 100\n--   \set nside 1024

\set nside 1024

WITH params AS (
  SELECT
    ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom,
    LEAST(
      healpix_ang2ipix_nest(:nside, :minx, :miny),
      healpix_ang2ipix_nest(:nside, :maxx, :miny),
      healpix_ang2ipix_nest(:nside, :maxx, :maxy),
      healpix_ang2ipix_nest(:nside, :minx, :maxy)
    ) AS ipix_min,
    GREATEST(
      healpix_ang2ipix_nest(:nside, :minx, :miny),
      healpix_ang2ipix_nest(:nside, :maxx, :miny),
      healpix_ang2ipix_nest(:nside, :maxx, :maxy),
      healpix_ang2ipix_nest(:nside, :minx, :maxy)
    ) AS ipix_max
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_healpix h
  ON p.osm_id = h.osm_id
JOIN params ON true
WHERE h.ipix BETWEEN params.ipix_min AND params.ipix_max
  AND p.way && params.geom
  AND ST_Intersects(p.way, params.geom)
LIMIT :limit;
