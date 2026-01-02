CREATE TABLE IF NOT EXISTS planet_osm_point_q3c AS
SELECT
  osm_id,
  ST_X(way) AS lon,
  ST_Y(way) AS lat
FROM planet_osm_point
WHERE way IS NOT NULL;
