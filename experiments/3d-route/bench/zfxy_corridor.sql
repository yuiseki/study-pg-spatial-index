-- zfxy_corridor: zfxy 3D cell range scan + PostGIS + height recheck.
--
-- Strategy:
--   1. Compute tile x/y/f range for corridor bbox + altitude band
--   2. Scan planet_osm_building_zfxy_3d via (resolution, f, x, y) B-tree
--   3. Join building_height_model for geometry bbox + ST_Intersects recheck
--   4. Numeric height recheck to eliminate f-granularity false positives
--
-- NOTE: At z=19, f granularity = 64 m/unit.
--   altitude=30 m ± 5 m → f_min=f_max=0 (no 3D selectivity)
--   altitude=90 m ± 5 m → f=1 only (first altitude where f helps)
-- This structural limitation is part of what this bench measures.
--
-- Variables (psql):
--   \set altitude_m   30
--   \set clearance_m  5
--   \set resolution   19

-- altitude_m, clearance_m, resolution must be passed via psql -v (no \set defaults here)

WITH corridor AS (
  SELECT
    zfxy_x(r.corridor_minx, :resolution)                                   AS x_min,
    zfxy_x(r.corridor_maxx, :resolution)                                   AS x_max,
    zfxy_y(r.corridor_maxy, :resolution)                                   AS y_min,
    zfxy_y(r.corridor_miny, :resolution)                                   AS y_max,
    zfxy_f((r.altitude_m - r.clearance_m)::double precision, :resolution)  AS f_min,
    zfxy_f((r.altitude_m + r.clearance_m)::double precision, :resolution)  AS f_max,
    r.geom,
    r.height_min_m,
    r.height_max_m
  FROM route_corridor r
  WHERE r.altitude_m = :altitude_m AND r.clearance_m = :clearance_m
  LIMIT 1
)
SELECT DISTINCT
  bhm.osm_id,
  bhm.max_height_m,
  bhm.min_height_m,
  bhm.height_source
FROM corridor c
JOIN planet_osm_building_zfxy_3d z
  ON z.resolution = :resolution
 AND z.f BETWEEN c.f_min AND c.f_max
 AND z.x BETWEEN c.x_min AND c.x_max
 AND z.y BETWEEN c.y_min AND c.y_max
JOIN building_height_model bhm
  ON bhm.osm_id = z.osm_id
 AND bhm.geom && c.geom
 AND ST_Intersects(bhm.geom, c.geom)
 AND bhm.max_height_m >= c.height_min_m
 AND bhm.min_height_m <= c.height_max_m
ORDER BY bhm.osm_id;
