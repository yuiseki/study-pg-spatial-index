CREATE INDEX IF NOT EXISTS planet_osm_point_q3c_ang2ipix_idx
  ON planet_osm_point_q3c (q3c_ang2ipix(lon, lat));
