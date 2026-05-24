-- planet_osm_building_zfxy_3d: 3D zfxy cell table for buildings.
--
-- Design:
--   x, y: footprint bbox tile cover (same as 2D cover)
--   f:    floor(2^z * height_m / 2^25)
--         f_min from min_height_m, f_max from max_height_m
--         cells are expanded over f_min..f_max
--
-- IMPORTANT — f granularity analysis (Taito-ku data):
--   z=17: 256 m/f-unit  → all buildings f=0 (useless)
--   z=18: 128 m/f-unit  → buildings <128 m: f=0 (99.9%)
--   z=19:  64 m/f-unit  → buildings <64 m:  f=0 (99.7%)
--   z=21:  16 m/f-unit  → per ~5-floor granularity
--   z=22:   8 m/f-unit  → per ~2-floor granularity
--
-- At z=17–19 the f filter provides no meaningful selectivity for Taito-ku.
-- This table exists to MEASURE that finding, not to overcome it.
--
-- Safety caps:
--   xy_cap:  (x_max-x_min+1)*(y_max-y_min+1) <= 100  (footprint tiles)
--   fxy_cap: xy_cap * (f_max-f_min+1) <= 500          (total 3D cells per building)
--   Skipped buildings are logged to building_zfxy_3d_skipped.

\set resolution 19
\set xy_cap     100
\set fxy_cap    500

-- 3D cell table
CREATE TABLE IF NOT EXISTS planet_osm_building_zfxy_3d (
  osm_id        BIGINT           NOT NULL,
  resolution    INTEGER          NOT NULL,
  f             BIGINT           NOT NULL,
  x             BIGINT           NOT NULL,
  y             BIGINT           NOT NULL,
  cell_id       TEXT             NOT NULL,
  height_source TEXT,
  min_height_m  DOUBLE PRECISION,
  max_height_m  DOUBLE PRECISION,
  PRIMARY KEY (osm_id, resolution, f, x, y)
);

-- Skipped-buildings log
CREATE TABLE IF NOT EXISTS building_zfxy_3d_skipped (
  osm_id         BIGINT   NOT NULL,
  resolution     INTEGER  NOT NULL,
  skip_reason    TEXT     NOT NULL,
  xy_tiles       INTEGER,
  f_levels       INTEGER,
  fxy_cells      INTEGER,
  PRIMARY KEY (osm_id, resolution)
);

DELETE FROM planet_osm_building_zfxy_3d  WHERE resolution = :resolution;
DELETE FROM building_zfxy_3d_skipped     WHERE resolution = :resolution;

-- Populate skipped log
INSERT INTO building_zfxy_3d_skipped (osm_id, resolution, skip_reason, xy_tiles, f_levels, fxy_cells)
WITH bbox AS (
  SELECT
    b.osm_id,
    (zfxy_x(ST_XMax(b.geom), :resolution) - zfxy_x(ST_XMin(b.geom), :resolution) + 1)
    * (zfxy_y(ST_YMin(b.geom), :resolution) - zfxy_y(ST_YMax(b.geom), :resolution) + 1)
      AS xy_tiles,
    (zfxy_f(b.max_height_m, :resolution) - zfxy_f(b.min_height_m, :resolution) + 1)
      AS f_levels
  FROM building_height_model b
  WHERE b.geom IS NOT NULL AND b.max_height_m IS NOT NULL
)
SELECT
  osm_id,
  :resolution,
  CASE
    WHEN xy_tiles > :xy_cap          THEN 'xy_cap_exceeded'
    WHEN xy_tiles * f_levels > :fxy_cap THEN 'fxy_cap_exceeded'
  END AS skip_reason,
  xy_tiles,
  f_levels,
  xy_tiles * f_levels AS fxy_cells
FROM bbox
WHERE xy_tiles > :xy_cap OR xy_tiles * f_levels > :fxy_cap;

-- Populate 3D cells
INSERT INTO planet_osm_building_zfxy_3d
  (osm_id, resolution, f, x, y, cell_id, height_source, min_height_m, max_height_m)
WITH bbox AS (
  SELECT
    b.osm_id,
    b.min_height_m,
    b.max_height_m,
    b.height_source,
    zfxy_x(ST_XMin(b.geom), :resolution) AS x_min,
    zfxy_x(ST_XMax(b.geom), :resolution) AS x_max,
    zfxy_y(ST_YMax(b.geom), :resolution) AS y_min,
    zfxy_y(ST_YMin(b.geom), :resolution) AS y_max,
    zfxy_f(b.min_height_m,  :resolution) AS f_min,
    zfxy_f(b.max_height_m,  :resolution) AS f_max
  FROM building_height_model b
  WHERE b.geom IS NOT NULL AND b.max_height_m IS NOT NULL
),
filtered AS (
  SELECT *
  FROM bbox
  WHERE (x_max - x_min + 1) * (y_max - y_min + 1) <= :xy_cap
    AND (x_max - x_min + 1) * (y_max - y_min + 1)
        * (f_max - f_min + 1) <= :fxy_cap
)
SELECT
  f2.osm_id,
  :resolution        AS resolution,
  tf.f,
  tx.x,
  ty.y,
  zfxy_cell_text(:resolution, tf.f, tx.x, ty.y) AS cell_id,
  f2.height_source,
  f2.min_height_m,
  f2.max_height_m
FROM filtered f2
CROSS JOIN LATERAL generate_series(f2.f_min, f2.f_max) AS tf(f)
CROSS JOIN LATERAL generate_series(f2.x_min, f2.x_max) AS tx(x)
CROSS JOIN LATERAL generate_series(f2.y_min, f2.y_max) AS ty(y)
ON CONFLICT (osm_id, resolution, f, x, y) DO NOTHING;

-- Summary stats
SELECT
  (SELECT COUNT(DISTINCT osm_id) FROM building_height_model)   AS total_buildings,
  (SELECT COUNT(DISTINCT osm_id) FROM planet_osm_building_zfxy_3d WHERE resolution = :resolution) AS buildings_with_cells,
  (SELECT COUNT(*) FROM planet_osm_building_zfxy_3d WHERE resolution = :resolution)               AS total_3d_cells,
  (SELECT COUNT(*) FROM planet_osm_building_zfxy_3d WHERE resolution = :resolution AND f = 0)     AS cells_f_eq_0,
  (SELECT COUNT(*) FROM planet_osm_building_zfxy_3d WHERE resolution = :resolution AND f > 0)     AS cells_f_gt_0,
  (SELECT COUNT(*) FROM building_zfxy_3d_skipped WHERE resolution = :resolution)                  AS skipped_buildings;
