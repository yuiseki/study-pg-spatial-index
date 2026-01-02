CREATE INDEX IF NOT EXISTS planet_osm_point_pgsphere_spoint_gist
  ON planet_osm_point_pgsphere USING GIST (spoint);
