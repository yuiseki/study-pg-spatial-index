-- route_corridor: South–North fixed corridor definitions for Taito-ku.
--
-- Corridor geometry:
--   Center line: lon=139.785, lat 35.695 → 35.731 (south→north, Taito-ku)
--   Width: 100 m
--   At 35.7°N: 1° lon ≈ 90,900 m → 100 m ≈ 0.001100° lon, half = 0.000550°
--
-- Altitude levels: 30 m / 60 m / 90 m / 120 m  (drone flight altitudes)
-- Clearance: 5 m above and below the nominal altitude
--
-- NOTE: This is a rectangular bounding-box approximation of the corridor.
--       It is not a swept-circle or true offset polygon.
--       False positives at corridor edges are expected and are part of the comparison.

DROP TABLE IF EXISTS route_corridor;

CREATE TABLE route_corridor (
  corridor_id     SERIAL PRIMARY KEY,
  label           TEXT   NOT NULL,
  altitude_m      DOUBLE PRECISION NOT NULL,
  clearance_m     DOUBLE PRECISION NOT NULL,
  height_min_m    DOUBLE PRECISION NOT NULL,
  height_max_m    DOUBLE PRECISION NOT NULL,
  corridor_minx   DOUBLE PRECISION NOT NULL,
  corridor_miny   DOUBLE PRECISION NOT NULL,
  corridor_maxx   DOUBLE PRECISION NOT NULL,
  corridor_maxy   DOUBLE PRECISION NOT NULL,
  geom            GEOMETRY(POLYGON, 4326) NOT NULL
);

INSERT INTO route_corridor
  (label, altitude_m, clearance_m, height_min_m, height_max_m,
   corridor_minx, corridor_miny, corridor_maxx, corridor_maxy, geom)
SELECT
  'alt' || alt || 'm_clear5m' AS label,
  alt                          AS altitude_m,
  5.0                          AS clearance_m,
  alt - 5.0                    AS height_min_m,
  alt + 5.0                    AS height_max_m,
  139.784450                   AS corridor_minx,
  35.695000                    AS corridor_miny,
  139.785550                   AS corridor_maxx,
  35.731000                    AS corridor_maxy,
  ST_MakeEnvelope(139.784450, 35.695000, 139.785550, 35.731000, 4326) AS geom
FROM unnest(ARRAY[30, 60, 90, 120]) AS alt;

SELECT corridor_id, label, altitude_m, height_min_m, height_max_m FROM route_corridor;
