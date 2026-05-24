-- Indexes for baseline (PostGIS GiST + numeric height range) and zfxy_3d.

-- baseline: GiST on geometry
CREATE INDEX IF NOT EXISTS building_height_model_geom_gist
  ON building_height_model USING gist (geom);

-- baseline: composite range index for height filter (useful for ceiling queries)
CREATE INDEX IF NOT EXISTS building_height_model_height_range
  ON building_height_model (max_height_m, min_height_m);

-- baseline: single-column index for max_height_m (range scans from above)
CREATE INDEX IF NOT EXISTS building_height_model_max_height
  ON building_height_model (max_height_m);

-- zfxy_3d: composite B-tree on (resolution, f, x, y) for range scan
-- PK covers (osm_id, resolution, f, x, y); add a covering index for the
-- range-query access pattern (resolution, f, x, y) → osm_id.
CREATE INDEX IF NOT EXISTS building_zfxy_3d_rfxy
  ON planet_osm_building_zfxy_3d (resolution, f, x, y);

ANALYZE building_height_model;
ANALYZE planet_osm_building_zfxy_3d;

-- Index sizes
SELECT
  c.relname            AS object_name,
  c.relkind            AS kind,
  pg_size_pretty(pg_relation_size(c.oid))  AS data_size,
  pg_size_pretty(pg_indexes_size(c.oid))   AS indexes_size,
  pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class c
WHERE c.relname IN (
  'building_height_model',
  'planet_osm_building_zfxy_3d',
  'planet_osm_polygon_zfxy',
  'planet_osm_polygon'
)
ORDER BY pg_total_relation_size(c.oid) DESC;
