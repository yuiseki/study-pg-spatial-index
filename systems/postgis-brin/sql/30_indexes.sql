-- OSM default.style tables (osm2pgsql)
CREATE INDEX IF NOT EXISTS planet_osm_point_way_brin
  ON planet_osm_point
  USING BRIN (way);

CREATE INDEX IF NOT EXISTS planet_osm_line_way_brin
  ON planet_osm_line
  USING BRIN (way);

CREATE INDEX IF NOT EXISTS planet_osm_polygon_way_brin
  ON planet_osm_polygon
  USING BRIN (way);

CREATE INDEX IF NOT EXISTS planet_osm_roads_way_brin
  ON planet_osm_roads
  USING BRIN (way);
