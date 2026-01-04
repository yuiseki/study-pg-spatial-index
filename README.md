# study-pg-spatial-index

PostgreSQL で使える複数の空間インデックス方式を、同一データ・同一クエリで比較するための検証リポジトリです。PostGIS の空間 AM（GiST / SP-GiST / BRIN など）と、DGGS/セル ID 設計（H3 / GeoHash / S2 / Q3C / HEALPix など）を並列に立ち上げ、`EXPLAIN (ANALYZE, BUFFERS)` を収集します。

## 目的・スコープ
- **PostGIS の空間 AM**: geometry/geography 列に対する空間インデックス（GiST / SP-GiST / BRIN）
- **セル ID 設計（DGGS）**: セル ID 列 + B-tree で候補抽出し、PostGIS 等で recheck
- 点（Points）と面（Polygons）の固定クエリセットで比較

詳細な方針は `TODO.md` を参照してください。

## ディレクトリ構成
- `common/sql/`: 共通スキーマ（places / buildings）と Overture CSV 取り込み用 SQL
- `common/bench/`: 共通ベンチ用 SQL（points / polygons）
- `common/scripts/`: ベンチ実行・EXPLAIN 取得・OSM AOI 補助スクリプト
- `systems/<system>/sql/`: 拡張ごとの init SQL（extension / cells / index / analyze）
- `systems/<system>/bench/`: system 固有のベンチ SQL（あれば優先）
- `data/`: OSM 関連データ（AOI / extract など）
- `results/`: 実行結果の保存先（大きくなりやすい）

## 主要コンポーネント

### Docker 構成
`docker-compose.yml` で拡張ごとの Postgres コンテナを分離しています。各サービスは `profiles` で起動します。

例: PostGIS + GiST
```
make up-postgis-gist
```

### 利用拡張
`systems/*/sql/00_extensions.sql` に定義されています。
- PostGIS: GiST / SP-GiST / BRIN
- H3, Q3C, HEALPix, pgSphere, GeoHash（PostGIS / pg_geohash）など

### インデックス/セル設計
`systems/*/sql/25_cells_schema.sql` と `systems/*/sql/30_indexes.sql` を参照してください。

## セットアップ手順（例）

### 1. OSM データを AOI で抽出
`Makefile` では `osmium extract` を使った AOI 抽出を用意しています。

```
# AOI GeoJSON を .poly に変換
make osm-aoi-poly \
  OSM_AOI_GEOJSON=path/to/aoi.geojson \
  OSM_AOI_POLY=data/osm/aoi/taito-ku.poly

# OSM PBF から AOI を抽出
make osm-extract \
  OSM_PBF=/path/to/japan.osm.pbf \
  OSM_EXTRACT=data/osm/extract/taito-ku.osm.pbf \
  OSM_AOI_POLY=data/osm/aoi/taito-ku.poly
```

※ `Makefile` の既定値はローカル環境依存です。手元のパスに合わせて `OSM_PBF` / `OSM_AOI_GEOJSON` を指定してください。

### 2. コンテナ起動
```
# 例: PostGIS + GiST
make up-postgis-gist
```

### 3. OSM データを import（osm2pgsql）
```
make osm-import-default \
  PGHOST=localhost \
  PGPORT=5432 \
  PGDATABASE=postgres \
  PGUSER=postgres \
  PGPASSWORD=postgres \
  OSM_EXTRACT=data/osm/extract/taito-ku.osm.pbf
```

### 4. 必要な拡張を有効化
```
make db-enable-extensions \
  PGHOST=localhost \
  PGPORT=5432 \
  PGDATABASE=postgres \
  PGUSER=postgres \
  PGPASSWORD=postgres
```

### 5. ベンチマーク実行
```
# 例: postgis-gist のベンチ実行
make bench-postgis-gist
```

実行結果は `results/<system>/<timestamp>/explain/` に保存されます。

## ベンチマーク内容
`common/bench/` の SQL を基本として、`systems/<system>/bench/` があればそちらを優先します。

- Points: Viewport / Radius / kNN
- Polygons: Viewport / Point-in-Polygon

## 補足（Overture データ）
`common/sql/20_load_places.sql` / `21_load_buildings.sql` は Overture の CSV から取り込むための SQL です。`/data/overture/prepared/places.csv` と `/data/overture/prepared/buildings.csv` をコンテナ内に用意する必要があります。

## 注意点
- `pgs2` は現状 Dockerfile でビルドが失敗するため無効化されています（`WITH_PGS2=1` で失敗します）。
- `pg_geohash` は PostgreSQL 17 向けに軽微なパッチを当ててビルドしています。
- `results/` は巨大になりやすいので、必要に応じて整理してください。

## 参考
- 実験の意図や比較観点は `TODO.md` に詳しく記載されています。
