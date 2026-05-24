-- zfxy cell assignment tables.
--
-- MVP scope:
--   - h = 0 for all records; f = 0 throughout.
--   - This is NOT a 3D performance test.  The purpose is to evaluate zfxy as a
--     spatial key design (cell ID + B-tree) on PostgreSQL against existing
--     PostGIS / H3 / GeoHash / Q3C / HEALPix approaches.
--   - resolution = z (the zfxy zoom level used for indexing).

\set resolution 15

-- ----------------------------------------------------------------
-- Points
-- ----------------------------------------------------------------
-- Composite PK (osm_id, resolution) to support multi-resolution population.
-- Single-resolution systems like H3 use osm_id as PK; zfxy supports sweep.
CREATE TABLE IF NOT EXISTS planet_osm_point_zfxy (
  osm_id     BIGINT  NOT NULL,
  resolution INTEGER NOT NULL,
  f          BIGINT  NOT NULL,
  x          BIGINT  NOT NULL,
  y          BIGINT  NOT NULL,
  cell_id    TEXT    NOT NULL,
  PRIMARY KEY (osm_id, resolution)
);

DELETE FROM planet_osm_point_zfxy WHERE resolution = :resolution;

INSERT INTO planet_osm_point_zfxy (osm_id, resolution, f, x, y, cell_id)
SELECT
  osm_id,
  :resolution                                                       AS resolution,
  0::BIGINT                                                         AS f,
  zfxy_x(ST_X(way), :resolution)                                   AS x,
  zfxy_y(ST_Y(way), :resolution)                                   AS y,
  zfxy_cell_text(
    :resolution,
    0::BIGINT,
    zfxy_x(ST_X(way), :resolution),
    zfxy_y(ST_Y(way), :resolution)
  )                                                                 AS cell_id
FROM planet_osm_point
WHERE way IS NOT NULL
ON CONFLICT (osm_id, resolution) DO UPDATE
  SET f       = EXCLUDED.f,
      x       = EXCLUDED.x,
      y       = EXCLUDED.y,
      cell_id = EXCLUDED.cell_id;

-- ----------------------------------------------------------------
-- Polygons  (bbox tile cover, f = 0)
--
-- IMPORTANT LIMITATIONS (intentional, not an oversight):
--   1. This is a *bbox* cover, not a strict polygon cover.
--      Tiles that overlap the bbox but NOT the actual geometry will be
--      included as false positives → PostGIS recheck is mandatory.
--   2. There is no equivalent to H3 polyfill / S2 covering here.
--      The difference in false-positive rate between this approach and
--      mature polyfill implementations is itself an observation target.
--   3. Polygons whose bbox spans > 100 tiles at this resolution are skipped
--      to avoid runaway INSERT during init.  Large park / district polygons
--      are excluded from the comparison at this resolution.
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS planet_osm_polygon_zfxy (
  osm_id     BIGINT  NOT NULL,
  resolution INTEGER NOT NULL,
  f          BIGINT  NOT NULL,
  x          BIGINT  NOT NULL,
  y          BIGINT  NOT NULL,
  cell_id    TEXT    NOT NULL,
  PRIMARY KEY (osm_id, cell_id)
);

DELETE FROM planet_osm_polygon_zfxy WHERE resolution = :resolution;

INSERT INTO planet_osm_polygon_zfxy (osm_id, resolution, f, x, y, cell_id)
WITH bbox AS (
  SELECT
    osm_id,
    zfxy_x(ST_XMin(way), :resolution) AS x_min,
    zfxy_x(ST_XMax(way), :resolution) AS x_max,
    -- Y is inverted: higher latitude → smaller y
    zfxy_y(ST_YMax(way), :resolution) AS y_min,
    zfxy_y(ST_YMin(way), :resolution) AS y_max
  FROM planet_osm_polygon
  WHERE way IS NOT NULL
),
-- Safety cap: skip bbox covers that would expand to > 100 tiles
filtered AS (
  SELECT * FROM bbox
  WHERE (x_max - x_min + 1) * (y_max - y_min + 1) <= 100
)
SELECT
  f.osm_id,
  :resolution                                        AS resolution,
  0::BIGINT                                          AS f,
  tx.x,
  ty.y,
  zfxy_cell_text(:resolution, 0::BIGINT, tx.x, ty.y) AS cell_id
FROM filtered f
CROSS JOIN LATERAL generate_series(f.x_min, f.x_max) AS tx(x)
CROSS JOIN LATERAL generate_series(f.y_min, f.y_max) AS ty(y)
ON CONFLICT (osm_id, cell_id) DO NOTHING;
