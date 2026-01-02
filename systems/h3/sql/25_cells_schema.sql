\set resolution 9

CREATE TABLE IF NOT EXISTS planet_osm_point_h3 (
  osm_id BIGINT PRIMARY KEY,
  h3_cell h3index NOT NULL,
  resolution INTEGER NOT NULL
);

DELETE FROM planet_osm_point_h3 WHERE resolution = :resolution;

INSERT INTO planet_osm_point_h3 (osm_id, h3_cell, resolution)
SELECT
  osm_id,
  h3_latlng_to_cell(point(ST_X(way), ST_Y(way)), :resolution),
  :resolution
FROM planet_osm_point
WHERE way IS NOT NULL
ON CONFLICT (osm_id) DO UPDATE
  SET h3_cell = EXCLUDED.h3_cell,
      resolution = EXCLUDED.resolution;
