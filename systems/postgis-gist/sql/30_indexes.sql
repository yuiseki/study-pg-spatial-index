-- OSM default.style tables (osm2pgsql)
CREATE INDEX IF NOT EXISTS planet_osm_point_way_gist
  ON planet_osm_point
  USING GIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_line_way_gist
  ON planet_osm_line
  USING GIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_polygon_way_gist
  ON planet_osm_polygon
  USING GIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_roads_way_gist
  ON planet_osm_roads
  USING GIST (way);
