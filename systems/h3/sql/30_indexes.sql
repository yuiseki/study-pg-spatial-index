CREATE INDEX IF NOT EXISTS planet_osm_point_h3_res_cell_btree
  ON planet_osm_point_h3 (resolution, h3_cell);
