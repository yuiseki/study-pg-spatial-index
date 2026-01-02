CREATE INDEX IF NOT EXISTS planet_osm_point_s2_cell_idx
  ON planet_osm_point_s2 (s2_cell);
