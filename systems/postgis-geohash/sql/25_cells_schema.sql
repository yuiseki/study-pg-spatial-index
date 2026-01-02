\set precision 7

CREATE TABLE IF NOT EXISTS planet_osm_point_geohash (
  osm_id BIGINT PRIMARY KEY,
  geohash TEXT NOT NULL,
  precision INTEGER NOT NULL
);

DELETE FROM planet_osm_point_geohash WHERE precision = :precision;

INSERT INTO planet_osm_point_geohash (osm_id, geohash, precision)
SELECT
  osm_id,
  ST_GeoHash(way, :precision),
  :precision
FROM planet_osm_point
WHERE way IS NOT NULL
ON CONFLICT (osm_id) DO UPDATE
  SET geohash = EXCLUDED.geohash,
      precision = EXCLUDED.precision;
