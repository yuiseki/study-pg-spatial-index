CREATE INDEX IF NOT EXISTS planet_osm_point_pg_geohash_prefix_idx
  ON planet_osm_point_pg_geohash (precision, geohash text_pattern_ops);
