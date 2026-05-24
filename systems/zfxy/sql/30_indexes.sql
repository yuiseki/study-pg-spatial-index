-- zfxy B-tree indexes.
--
-- Three index strategies are created so EXPLAIN (ANALYZE, BUFFERS) can show
-- which one the planner selects for each query type:
--
--   idx_res_cell   : (resolution, cell_id) with text_pattern_ops
--                    → prefix / equality lookup on the text key
--   idx_res_xy     : (resolution, x, y)
--                    → 2-D tile-range scan (viewport, radius, kNN candidates)
--   idx_res_fxy    : (resolution, f, x, y)
--                    → full 3-D tile-range scan (future 3D queries; f=0 in MVP)

-- ---- Points ---------------------------------------------------------------

CREATE INDEX IF NOT EXISTS planet_osm_point_zfxy_res_cell_btree
  ON planet_osm_point_zfxy (resolution, cell_id text_pattern_ops);

CREATE INDEX IF NOT EXISTS planet_osm_point_zfxy_res_xy_btree
  ON planet_osm_point_zfxy (resolution, x, y);

CREATE INDEX IF NOT EXISTS planet_osm_point_zfxy_res_fxy_btree
  ON planet_osm_point_zfxy (resolution, f, x, y);

-- ---- Polygons -------------------------------------------------------------

CREATE INDEX IF NOT EXISTS planet_osm_polygon_zfxy_res_cell_btree
  ON planet_osm_polygon_zfxy (resolution, cell_id text_pattern_ops);

CREATE INDEX IF NOT EXISTS planet_osm_polygon_zfxy_res_xy_btree
  ON planet_osm_polygon_zfxy (resolution, x, y);

CREATE INDEX IF NOT EXISTS planet_osm_polygon_zfxy_res_fxy_btree
  ON planet_osm_polygon_zfxy (resolution, f, x, y);
