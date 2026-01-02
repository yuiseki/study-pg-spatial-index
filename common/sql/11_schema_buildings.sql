CREATE TABLE IF NOT EXISTS buildings (
  id TEXT PRIMARY KEY,
  geom geometry(MultiPolygon, 4326) NOT NULL,
  props JSONB
);
