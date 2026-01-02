-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set limit 100\n--   \set precision 7\n--   \set radius_m 2000

\set precision 7
\set radius_m 2000

WITH params AS (
  SELECT
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center,
    :radius_m::double precision AS radius_m,
    :precision::int AS precision
),
poly AS (
  SELECT ST_Buffer(center::geography, radius_m)::geometry AS geom
  FROM params
),
step AS (
  SELECT CASE (SELECT precision FROM params)
    WHEN 5 THEN 0.0439453125
    WHEN 6 THEN 0.0109863281
    WHEN 7 THEN 0.0027465820
    WHEN 8 THEN 0.0006866455
    ELSE 0.0109863281
  END AS deg
),
points AS (
  SELECT
    ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS geom
  FROM poly, step,
       generate_series(ST_XMin(geom)::numeric, ST_XMax(geom)::numeric, step.deg::numeric) AS lon,
       generate_series(ST_YMin(geom)::numeric, ST_YMax(geom)::numeric, step.deg::numeric) AS lat
),
geohashes AS (
  SELECT DISTINCT ST_GeoHash(geom, (SELECT precision FROM params)) AS geohash
  FROM points
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_geohash g
  ON p.osm_id = g.osm_id
 AND g.precision = (SELECT precision FROM params)
JOIN geohashes h
  ON g.geohash LIKE h.geohash || '%'
ORDER BY p.way <-> (SELECT center FROM params)
LIMIT :limit;
