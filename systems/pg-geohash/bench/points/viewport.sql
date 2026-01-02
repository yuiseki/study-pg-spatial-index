-- Variables (psql):\n--   \set minx 139.77\n--   \set miny 35.71\n--   \set maxx 139.79\n--   \set maxy 35.73\n--   \set limit 100\n--   \set precision 7

\set precision 7

WITH params AS (
  SELECT
    :minx::double precision AS minx,
    :miny::double precision AS miny,
    :maxx::double precision AS maxx,
    :maxy::double precision AS maxy,
    :precision::int AS precision
),
step AS (
  SELECT CASE precision
    WHEN 5 THEN 0.0439453125
    WHEN 6 THEN 0.0109863281
    WHEN 7 THEN 0.0027465820
    WHEN 8 THEN 0.0006866455
    ELSE 0.0109863281
  END AS deg
  FROM params
),
points AS (
  SELECT
    ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS geom
  FROM params, step,
       generate_series(params.minx::numeric, params.maxx::numeric, step.deg::numeric) AS lon,
       generate_series(params.miny::numeric, params.maxy::numeric, step.deg::numeric) AS lat
),
geohashes AS (
  SELECT DISTINCT geohash_encode(ST_Y(geom), ST_X(geom), (SELECT precision FROM params)) AS geohash
  FROM points
),
bbox AS (
  SELECT ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_pg_geohash g
  ON p.osm_id = g.osm_id
 AND g.precision = (SELECT precision FROM params)
JOIN geohashes h
  ON g.geohash LIKE h.geohash || '%'
WHERE p.way && (SELECT geom FROM bbox)
  AND ST_Intersects(p.way, (SELECT geom FROM bbox))
LIMIT :limit;
