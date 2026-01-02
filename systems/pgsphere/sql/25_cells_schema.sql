CREATE TABLE IF NOT EXISTS planet_osm_point_pgsphere AS
SELECT
  osm_id,
  ST_X(way) AS lon,
  ST_Y(way) AS lat,
  spoint_deg(ST_X(way), ST_Y(way)) AS spoint
FROM planet_osm_point
WHERE way IS NOT NULL;
