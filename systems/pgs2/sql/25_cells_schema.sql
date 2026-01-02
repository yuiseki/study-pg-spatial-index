CREATE TABLE IF NOT EXISTS planet_osm_point_s2 (
  osm_id BIGINT PRIMARY KEY,
  s2_cell S2Cell NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lon DOUBLE PRECISION NOT NULL
);

INSERT INTO planet_osm_point_s2 (osm_id, s2_cell, lat, lon)
SELECT
  osm_id,
  (S2LatLng(ST_Y(way), ST_X(way), true)::S2Cell),
  ST_Y(way),
  ST_X(way)
FROM planet_osm_point
WHERE way IS NOT NULL
ON CONFLICT (osm_id) DO UPDATE
  SET s2_cell = EXCLUDED.s2_cell,
      lat = EXCLUDED.lat,
      lon = EXCLUDED.lon;
