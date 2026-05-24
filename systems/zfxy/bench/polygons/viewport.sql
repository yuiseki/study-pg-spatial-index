-- zfxy: Polygons — Viewport / BBox search
--
-- Strategy:
--   1. Compute tile (x, y) range covering the query bbox.
--   2. Scan planet_osm_polygon_zfxy for cells in that range (B-tree).
--      Driving from the cover table avoids a cartesian-like loop that occurs
--      when the polygon GiST scan is used as the outer side.
--   3. Join to planet_osm_polygon on osm_id (PK lookup per candidate).
--   4. Recheck with PostGIS && and ST_Intersects to eliminate false positives
--      introduced by the bbox cover.
--
-- NOTE: At z=15, Taito-ku fits in ~8 tiles, so the tile range matches almost
-- all rows in the cover table.  Use z=17 or higher for useful selectivity in
-- dense urban areas.
--
-- Variables (psql):
--   \set minx 139.77
--   \set miny 35.71
--   \set maxx 139.79
--   \set maxy 35.73
--   \set limit 100
--   \set resolution 15

\set resolution 15

WITH tile_range AS (
  SELECT
    zfxy_x(:minx::double precision, :resolution) AS x_min,
    zfxy_x(:maxx::double precision, :resolution) AS x_max,
    zfxy_y(:maxy::double precision, :resolution) AS y_min,
    zfxy_y(:miny::double precision, :resolution) AS y_max,
    ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom
)
SELECT DISTINCT
  p.osm_id,
  p.way,
  p.name
FROM tile_range tr
JOIN planet_osm_polygon_zfxy z
  ON z.resolution = :resolution
 AND z.x BETWEEN tr.x_min AND tr.x_max
 AND z.y BETWEEN tr.y_min AND tr.y_max
JOIN planet_osm_polygon p
  ON p.osm_id = z.osm_id
 AND p.way && tr.geom
 AND ST_Intersects(p.way, tr.geom)
LIMIT :limit;
