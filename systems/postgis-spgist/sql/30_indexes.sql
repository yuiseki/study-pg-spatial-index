-- OSM default.style tables (osm2pgsql)
CREATE INDEX IF NOT EXISTS planet_osm_point_way_spgist
  ON planet_osm_point
  USING SPGIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_line_way_spgist
  ON planet_osm_line
  USING SPGIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_polygon_way_spgist
  ON planet_osm_polygon
  USING SPGIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_roads_way_spgist
  ON planet_osm_roads
  USING SPGIST (way);
