-- Assumes /data is mounted read-only in the container
CREATE TEMP TABLE buildings_load (
  id TEXT,
  wkt TEXT,
  props JSONB
);

COPY buildings_load (id, wkt, props)
  FROM '/data/overture/prepared/buildings.csv'
  WITH (FORMAT csv, HEADER true);

INSERT INTO buildings (id, geom, props)
SELECT
  id,
  ST_GeomFromText(wkt, 4326),
  props
FROM buildings_load
ON CONFLICT (id) DO NOTHING;
