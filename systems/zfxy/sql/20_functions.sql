-- zfxy spatial key functions (pure SQL/PLpgSQL, no extension dependency).
--
-- Spec: https://github.com/unvt/zfxy-spec
-- Formulas:
--   n = 2^z
--   Z = 25,  H = 2^Z m (= 33554432 m)
--   x = floor(n * ((lon + 180) / 360))
--   y = floor(n * (1 - ln(tan(lat_rad) + 1/cos(lat_rad)) / π) / 2)
--   f = floor(n * h / H)
--
-- Note: PostgreSQL's ln() is the natural log; log() is base-10.
-- The y formula is identical to the standard Web Mercator (Slippy Map) tiling.

-- zfxy_x: tile X coordinate from longitude and zoom level z.
CREATE OR REPLACE FUNCTION zfxy_x(lon double precision, z integer)
RETURNS bigint
LANGUAGE sql IMMUTABLE STRICT
AS $$
  SELECT floor(power(2, z) * ((lon + 180.0) / 360.0))::bigint;
$$;

-- zfxy_y: tile Y coordinate from latitude and zoom level z.
-- Y increases southward (north pole → y=0).
CREATE OR REPLACE FUNCTION zfxy_y(lat double precision, z integer)
RETURNS bigint
LANGUAGE plpgsql IMMUTABLE STRICT
AS $$
DECLARE
  lat_rad double precision := radians(lat);
  n       double precision := power(2, z);
BEGIN
  RETURN floor(
    n * (1.0 - ln(tan(lat_rad) + 1.0 / cos(lat_rad)) / pi()) / 2.0
  )::bigint;
END;
$$;

-- zfxy_f: vertical tile F coordinate from height h (metres) and zoom level z.
-- Z_TOP = 25, H_TOP = 2^25 m = 33554432 m.
-- At h = 0 (ground level), f = 0 always.
CREATE OR REPLACE FUNCTION zfxy_f(h double precision, z integer)
RETURNS bigint
LANGUAGE sql IMMUTABLE STRICT
AS $$
  SELECT floor(power(2, z) * h / power(2, 25))::bigint;
$$;

-- zfxy_cell_text: canonical text key "{z}/{f}/{x}/{y}".
-- Kept as a separate function so integer/binary encodings can be added later
-- without changing call sites.
CREATE OR REPLACE FUNCTION zfxy_cell_text(z integer, f bigint, x bigint, y bigint)
RETURNS text
LANGUAGE sql IMMUTABLE STRICT
AS $$
  SELECT z::text || '/' || f::text || '/' || x::text || '/' || y::text;
$$;
