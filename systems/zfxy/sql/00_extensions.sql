-- zfxy uses only built-in SQL/PLpgSQL; no extra extension is required.
-- PostGIS is still needed for recheck (ST_Intersects, ST_DWithin, ST_Contains).
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pageinspect;
