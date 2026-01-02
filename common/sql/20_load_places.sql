-- Assumes /data is mounted read-only in the container
CREATE TEMP TABLE places_load (
  id TEXT,
  lon DOUBLE PRECISION,
  lat DOUBLE PRECISION,
  wkt TEXT,
  props JSONB
);

COPY places_load (id, lon, lat, wkt, props)
  FROM '/data/overture/prepared/places.csv'
  WITH (FORMAT csv, HEADER true);

INSERT INTO places (id, geom, lon, lat, props)
SELECT
  id,
  ST_GeomFromText(wkt, 4326),
  lon,
  lat,
  props
FROM places_load
ON CONFLICT (id) DO NOTHING;
