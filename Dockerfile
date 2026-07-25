ARG PG_VERSION=18
ARG WITH_H3=0
ARG WITH_PG_GEOHASH=0
ARG WITH_PGS2=0
ARG WITH_Q3C=0
ARG WITH_PG_HEALPIX=0
ARG WITH_PGSPHERE=0
FROM postgres:${PG_VERSION}

ARG PG_VERSION=17
ARG WITH_H3=0
ARG WITH_PG_GEOHASH=0
ARG WITH_PGS2=0
ARG WITH_Q3C=0
ARG WITH_PG_HEALPIX=0
ARG WITH_PGSPHERE=0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-${PG_VERSION}-postgis-3 \
        postgresql-${PG_VERSION}-postgis-3-scripts \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$WITH_Q3C" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends \
        postgresql-${PG_VERSION}-q3c \
      && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$WITH_PG_HEALPIX" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        postgresql-server-dev-${PG_VERSION} \
      && rm -rf /var/lib/apt/lists/* \
      && mkdir -p /tmp/pg_healpix \
      && curl -L -o /tmp/pg_healpix.tar.gz https://github.com/segasai/pg_healpix/archive/refs/heads/master.tar.gz \
      && tar -xzf /tmp/pg_healpix.tar.gz -C /tmp/pg_healpix --strip-components=1 \
      && cd /tmp/pg_healpix \
      && make \
      && make install \
      && rm -rf /tmp/pg_healpix /tmp/pg_healpix.tar.gz; \
    fi

RUN if [ "$WITH_PGSPHERE" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends \
        postgresql-${PG_VERSION}-pgsphere \
      && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$WITH_H3" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        curl \
        postgresql-server-dev-${PG_VERSION} \
      && rm -rf /var/lib/apt/lists/* \
      && if apt-get update \
        && apt-get install -y --no-install-recommends postgresql-${PG_VERSION}-h3; then \
          true; \
        else \
          apt-get update \
          && apt-get install -y --no-install-recommends ca-certificates \
          && rm -rf /var/lib/apt/lists/* \
          && mkdir -p /tmp/h3-pg \
          && curl -L -o /tmp/h3-pg.tar.gz https://github.com/postgis/h3-pg/archive/refs/heads/main.tar.gz \
          && tar -xzf /tmp/h3-pg.tar.gz -C /tmp/h3-pg --strip-components=1 \
          && cmake -B /tmp/h3-pg/build /tmp/h3-pg \
          && cmake --build /tmp/h3-pg/build \
          && cmake --install /tmp/h3-pg/build --component h3-pg \
          && rm -rf /tmp/h3-pg /tmp/h3-pg.tar.gz; \
        fi; \
    fi

RUN if [ "$WITH_PG_GEOHASH" = "1" ]; then \
      apt-get update \
      && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        gnupg \
        postgresql-server-dev-${PG_VERSION} \
      && rm -rf /var/lib/apt/lists/* \
      && apt-get update \
      && apt-get install -y --no-install-recommends ca-certificates \
      && rm -rf /var/lib/apt/lists/* \
      && mkdir -p /tmp/pg_geohash \
      && curl -L -o /tmp/pg_geohash.tar.gz https://github.com/jistok/pg_geohash/archive/refs/heads/master.tar.gz \
      && tar -xzf /tmp/pg_geohash.tar.gz -C /tmp/pg_geohash --strip-components=1 \
      && cd /tmp/pg_geohash \
      && python3 -c "from pathlib import Path; path = Path('pg_geohash.c'); text = path.read_text(); needle = '#include \\\"postgres.h\\\"\\n'; insert = '#include \\\"postgres.h\\\"\\n#include \\\"utils/varlena.h\\\"\\n#include \\\"varatt.h\\\"\\n#ifndef SET_VARSIZE\\n#define SET_VARSIZE(PTR, len) SET_VARSIZE_4B(PTR, len)\\n#endif\\n#ifndef VARDATA\\n#define VARDATA(PTR) VARDATA_ANY(PTR)\\n#endif\\n#ifndef VARSIZE\\n#define VARSIZE(PTR) VARSIZE_ANY(PTR)\\n#endif\\n';\nif needle not in text: raise SystemExit('postgres.h include not found');\npath.write_text(text.replace(needle, insert, 1))" \
      && make \
      && make install \
      && rm -rf /tmp/pg_geohash /tmp/pg_geohash.tar.gz; \
    fi

RUN if [ "$WITH_PGS2" = "1" ]; then \
      echo "pgs2 is disabled (see TODO.md)"; \
      exit 1; \
    fi
