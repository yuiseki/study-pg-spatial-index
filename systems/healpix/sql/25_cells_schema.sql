CREATE TABLE IF NOT EXISTS planet_osm_point_healpix AS
SELECT
  osm_id,
  ST_X(way) AS lon,
  ST_Y(way) AS lat,
  healpix_ang2ipix_nest(1024, ST_X(way), ST_Y(way)) AS ipix
FROM planet_osm_point
WHERE way IS NOT NULL;
