-- zfxy: Polygons — Viewport / BBox search
--
-- Strategy:
--   1. Compute the tile (x, y) range that covers the query bbox.
--   2. Look up matching tiles in planet_osm_polygon_zfxy (B-tree range scan).
--   3. Recheck with PostGIS && and ST_Intersects.
--
-- False-positive rate is higher than H3/S2 polyfill because the polygon
-- cover table was built from bbox tiles, not strict polygon tiles.
-- Recheck (step 3) eliminates false positives from both sources.
--
-- Variables (psql):
--   \set minx 139.77
--   \set miny 35.71
--   \set maxx 139.79
--   \set maxy 35.73
--   \set limit 100
--   \set resolution 15

\set resolution 15

WITH params AS (
  SELECT ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom
),
tile_range AS (
  SELECT
    zfxy_x(:minx::double precision, :resolution) AS x_min,
    zfxy_x(:maxx::double precision, :resolution) AS x_max,
    zfxy_y(:maxy::double precision, :resolution) AS y_min,
    zfxy_y(:miny::double precision, :resolution) AS y_max
)
SELECT DISTINCT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_polygon p
JOIN planet_osm_polygon_zfxy z
  ON p.osm_id = z.osm_id
 AND z.resolution = :resolution
JOIN tile_range tr ON true
WHERE z.x BETWEEN tr.x_min AND tr.x_max
  AND z.y BETWEEN tr.y_min AND tr.y_max
  AND p.way && (SELECT geom FROM params)
  AND ST_Intersects(p.way, (SELECT geom FROM params))
LIMIT :limit;
