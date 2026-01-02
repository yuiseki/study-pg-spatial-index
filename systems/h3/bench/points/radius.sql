-- Variables (psql):\n--   \set lon 139.777\n--   \set lat 35.713\n--   \set radius_m 1000\n--   \set limit 100\n--   \set resolution 9

\set resolution 9

WITH params AS (
  SELECT
    ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS center,
    :radius_m::double precision AS radius_m
),
poly AS (
  SELECT
    ST_Buffer(center::geography, radius_m)::geometry AS geom,
    polygon(box(
      point(ST_XMin(ST_Envelope(ST_Buffer(center::geography, radius_m)::geometry)),
            ST_YMin(ST_Envelope(ST_Buffer(center::geography, radius_m)::geometry))),
      point(ST_XMax(ST_Envelope(ST_Buffer(center::geography, radius_m)::geometry)),
            ST_YMax(ST_Envelope(ST_Buffer(center::geography, radius_m)::geometry)))
    )) AS pg_poly
  FROM params
),
cell_candidates AS (
  SELECT h3_cell
  FROM poly,
       LATERAL h3_polygon_to_cells(poly.pg_poly, ARRAY[]::polygon[], :resolution) AS h3_cell(h3_cell)
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
WHERE ST_DWithin(p.way::geography, (SELECT center FROM params)::geography, (SELECT radius_m FROM params))
LIMIT :limit;
