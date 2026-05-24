-- building_height_model: OSM buildings with estimated height range.
--
-- Height estimation priority:
--   1. tags->'height'          (parse_height_m, handles "10 m", "12.5", etc.)
--   2. tags->'building:levels' (levels * 3.0 m/floor)
--   3. default_15m policy      (NULL → 15.0 m)
--
-- min_height_m:
--   1. tags->'min_height'      (parse_height_m)
--   2. tags->'building:min_level' * 3.0
--   3. 0.0
--
-- unknown_height_policy: 'default_15m' (can be changed by re-running with different default)

DROP TABLE IF EXISTS building_height_model;

CREATE TABLE building_height_model AS
SELECT
  osm_id,
  way AS geom,
  COALESCE(
    parse_height_m(tags -> 'height'),
    CASE
      WHEN tags ? 'building:levels'
           AND tags -> 'building:levels' ~ '^[0-9]+([.][0-9]+)?$'
      THEN (tags -> 'building:levels')::double precision * 3.0
      ELSE NULL
    END,
    15.0
  )                                                      AS max_height_m,
  COALESCE(
    parse_height_m(tags -> 'min_height'),
    CASE
      WHEN tags ? 'building:min_level'
           AND tags -> 'building:min_level' ~ '^[0-9]+([.][0-9]+)?$'
      THEN (tags -> 'building:min_level')::double precision * 3.0
      ELSE NULL
    END,
    0.0
  )                                                      AS min_height_m,
  CASE
    WHEN parse_height_m(tags -> 'height') IS NOT NULL
         THEN 'height'
    WHEN tags ? 'building:levels'
         AND tags -> 'building:levels' ~ '^[0-9]+([.][0-9]+)?$'
         THEN 'building:levels_estimated'
    ELSE 'default'
  END                                                    AS height_source,
  CASE
    WHEN tags ? 'building:levels'
         AND tags -> 'building:levels' ~ '^[0-9]+([.][0-9]+)?$'
    THEN (tags -> 'building:levels')::double precision
    ELSE NULL
  END                                                    AS levels,
  NULL::double precision                                 AS min_level
FROM planet_osm_polygon
WHERE building IS NOT NULL OR tags ? 'building';

-- Sanity check output
SELECT
  COUNT(*)                                               AS total,
  COUNT(*) FILTER (WHERE height_source = 'height')      AS src_height,
  COUNT(*) FILTER (WHERE height_source = 'building:levels_estimated') AS src_levels,
  COUNT(*) FILTER (WHERE height_source = 'default')     AS src_default,
  MIN(max_height_m)                                      AS min_max_h,
  MAX(max_height_m)                                      AS max_max_h,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY max_height_m) AS median_max_h
FROM building_height_model;
