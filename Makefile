OSM_PBF ?= /data/www/html/static/openstreetmap/region/japan-251231.osm.pbf
OSM_AOI_GEOJSON ?= data/overture/aoi/taito-ku.geojson
OSM_AOI_POLY ?= data/osm/aoi/taito-ku.poly
OSM_EXTRACT ?= data/osm/extract/taito-ku.osm.pbf
OSM2PGSQL_PREFIX ?= planet_osm
PGHOST ?= localhost
PGPORT ?= 5432
PGDATABASE ?= postgres
PGUSER ?= postgres
PGPASSWORD ?= postgres

.PHONY: osm-aoi-poly
osm-aoi-poly:
	common/scripts/osm/geojson_to_poly.py "$(OSM_AOI_GEOJSON)" "$(OSM_AOI_POLY)" "taito-ku"

.PHONY: osm-extract
osm-extract: osm-aoi-poly
	osmium extract --polygon "$(OSM_AOI_POLY)" --output "$(OSM_EXTRACT)" --overwrite --progress "$(OSM_PBF)"

.PHONY: up-postgis-gist
up-postgis-gist:
	docker compose --profile postgis-gist up -d --build

.PHONY: osm-import-default
osm-import-default:
	PGPASSWORD="$(PGPASSWORD)" osm2pgsql \
		--create \
		--slim \
		--latlong \
		--hstore \
		--database "$(PGDATABASE)" \
		--host "$(PGHOST)" \
		--port "$(PGPORT)" \
		--user "$(PGUSER)" \
		--prefix "$(OSM2PGSQL_PREFIX)" \
		"$(OSM_EXTRACT)"

.PHONY: db-enable-extensions
db-enable-extensions:
	PGPASSWORD="$(PGPASSWORD)" psql \
		--host "$(PGHOST)" \
		--port "$(PGPORT)" \
		--username "$(PGUSER)" \
		--dbname "$(PGDATABASE)" \
		--file "common/scripts/create_extensions.sql"

.PHONY: explain
explain:
	common/scripts/explain.sh "$(QUERY)" "$(OUT)" $(VARS)

.PHONY: bench-postgis-gist
bench-postgis-gist:
	common/scripts/run_bench.sh postgis-gist

.PHONY: bench-postgis-spgist
bench-postgis-spgist:
	common/scripts/run_bench.sh postgis-spgist

.PHONY: bench-postgis-brin
bench-postgis-brin:
	common/scripts/run_bench.sh postgis-brin

.PHONY: bench-h3
bench-h3:
	common/scripts/run_bench.sh h3

.PHONY: bench-q3c
bench-q3c:
	common/scripts/run_bench.sh q3c

.PHONY: bench-healpix
bench-healpix:
	common/scripts/run_bench.sh healpix

.PHONY: bench-pgsphere
bench-pgsphere:
	common/scripts/run_bench.sh pgsphere

.PHONY: bench-postgis-geohash
bench-postgis-geohash:
	common/scripts/run_bench.sh postgis-geohash

.PHONY: bench-pg-geohash
bench-pg-geohash:
	common/scripts/run_bench.sh pg-geohash

.PHONY: up-zfxy
up-zfxy:
	docker compose --profile zfxy up -d --build

.PHONY: bench-zfxy
bench-zfxy:
	common/scripts/run_bench.sh zfxy

# -----------------------------------------------------------------------
# 3D-ish route benchmark (separate from 2D spatial index comparison)
#   Target: zfxy container (PostGIS + zfxy functions), default port 55442
#   Override: make bench3d-route PGPORT=55442
# -----------------------------------------------------------------------
BENCH3D_PGPORT ?= 55442

.PHONY: bench3d-route
bench3d-route:
	PGHOST="$(PGHOST)" PGPORT="$(BENCH3D_PGPORT)" \
	PGDATABASE="$(PGDATABASE)" PGUSER="$(PGUSER)" PGPASSWORD="$(PGPASSWORD)" \
	experiments/3d-route/scripts/run_3d_route_bench.sh

.PHONY: bench3d-route-baseline
bench3d-route-baseline:
	PGHOST="$(PGHOST)" PGPORT="$(BENCH3D_PGPORT)" \
	PGDATABASE="$(PGDATABASE)" PGUSER="$(PGUSER)" PGPASSWORD="$(PGPASSWORD)" \
	common/scripts/explain.sh \
	    experiments/3d-route/bench/baseline_corridor.sql \
	    /dev/stdout \
	    altitude_m=30 clearance_m=5

.PHONY: bench3d-route-zfxy
bench3d-route-zfxy:
	PGHOST="$(PGHOST)" PGPORT="$(BENCH3D_PGPORT)" \
	PGDATABASE="$(PGDATABASE)" PGUSER="$(PGUSER)" PGPASSWORD="$(PGPASSWORD)" \
	common/scripts/explain.sh \
	    experiments/3d-route/bench/zfxy_corridor.sql \
	    /dev/stdout \
	    altitude_m=30 clearance_m=5 resolution=19
