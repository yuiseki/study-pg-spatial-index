-- parse_height_m(raw text) → double precision
--
-- Handles OSM height tag variants:
--   "8"          → 8.0
--   "10 m"       → 10.0
--   "12.5"       → 12.5
--   "10;12"      → 10.0  (first value)
--   "30 ft"      → 9.14
--   "10;12 m"    → 10.0
--   unparseable  → NULL
--
-- Values <= 0 or >= 9999 are treated as NULL (sanity guard).

CREATE OR REPLACE FUNCTION parse_height_m(raw text)
RETURNS double precision
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE
  first_val text;
  cleaned   text;
  val       double precision;
BEGIN
  first_val := trim(split_part(raw, ';', 1));
  IF first_val = '' THEN RETURN NULL; END IF;

  -- Feet → metres conversion
  IF first_val ~* '^[\d.]+\s*(ft|feet|foot)\s*$' THEN
    cleaned := regexp_replace(first_val, '\s*(ft|feet|foot)\s*$', '', 'i');
    BEGIN
      val := trim(cleaned)::double precision * 0.3048;
      IF val > 0 AND val < 9999 THEN RETURN round(val::numeric, 2)::double precision; END IF;
      RETURN NULL;
    EXCEPTION WHEN OTHERS THEN RETURN NULL;
    END;
  END IF;

  -- Strip metric unit suffix
  cleaned := regexp_replace(first_val, '\s*(m|meters?|metres?)\s*$', '', 'i');

  BEGIN
    val := trim(cleaned)::double precision;
    IF val > 0 AND val < 9999 THEN RETURN val; END IF;
    RETURN NULL;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$$;
