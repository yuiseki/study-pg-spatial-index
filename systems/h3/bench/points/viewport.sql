-- Variables (psql):\n--   \set minx 139.77\n--   \set miny 35.71\n--   \set maxx 139.79\n--   \set maxy 35.73\n--   \set limit 100\n--   \set resolution 9

\set resolution 9

WITH bbox AS (
  SELECT
    ST_MakeEnvelope(:minx, :miny, :maxx, :maxy, 4326) AS geom,
    polygon(box(point(:minx, :miny), point(:maxx, :maxy))) AS pg_poly
),
cell_candidates AS (
  SELECT h3_cell
  FROM bbox,
       LATERAL h3_polygon_to_cells(bbox.pg_poly, ARRAY[]::polygon[], :resolution) AS h3_cell(h3_cell)
)
SELECT
  p.osm_id,
  p.way,
  p.name
FROM planet_osm_point p
JOIN planet_osm_point_h3 h
  ON p.osm_id = h.osm_id
 AND h.resolution = :resolution
JOIN cell_candidates c
  ON h.h3_cell = c.h3_cell
WHERE p.way && (SELECT geom FROM bbox)
  AND ST_Intersects(p.way, (SELECT geom FROM bbox))
LIMIT :limit;
