# study-pg-spatial-index

PostgreSQL で使える複数の空間インデックス方式を、同一データ・同一クエリで比較するための検証リポジトリです。PostGIS の空間 AM（GiST / SP-GiST / BRIN など）と、DGGS/セル ID 設計（H3 / GeoHash / S2 / Q3C / HEALPix など）を並列に立ち上げ、`EXPLAIN (ANALYZE, BUFFERS)` を収集します。

## 目的・スコープ
- **PostGIS の空間 AM**: geometry/geography 列に対する空間インデックス（GiST / SP-GiST / BRIN）
- **セル ID 設計（DGGS）**: セル ID 列 + B-tree で候補抽出し、PostGIS 等で recheck
- 点（Points）と面（Polygons）の固定クエリセットで比較

詳細な方針は `TODO.md` を参照してください。

## zfxy について

`systems/zfxy/` は、[zfxy](https://github.com/unvt/zfxy-spec) を **PostGIS の空間 AM ではなく、セル ID 列 + 通常インデックス（B-tree）による空間キー設計** として追加したものです。

- この比較の目的は zfxy を否定または称賛することではありません。既存手法（PostGIS / H3 / GeoHash / Q3C / HEALPix）と同じ土俵に載せ、`EXPLAIN (ANALYZE, BUFFERS)` で差分を実測できるようにすることです。
- **MVP では高さ `h = 0` を固定し、`f = 0` として扱います。** これは 3D 性能の比較ではなく、zfxy を PostgreSQL 上の候補抽出キーとして扱えるかの最小検証です。
- **polygon cover は bbox タイルカバーであり、厳密な polygon cover ではありません。** H3 polyfill / S2 covering と同等ではなく、recheck（PostGIS ST_Intersects / ST_Contains）が必須です。false positive 率の差分そのものが観察対象です。
- zfxy には現時点で H3 / S2 のような成熟した covering / compact / neighbor traversal がないため、polygon cover と kNN は簡易実装 + PostGIS recheck 前提です。この不足点も比較の一部として記録します。

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

## 実測結果（zfxy 比較）

データ: OSM 台東区（点 25,833件 / 面 39,059件）、PostgreSQL 17、JIT off、ウォームキャッシュ。  
クエリ: 中心点 (139.777, 35.713)、半径 1km、LIMIT 100。

### radius 検索（1km）— 横断比較

| 方式 | 候補行数 | 実結果 | FP 率 | 実行時間 | 備考 |
|---|---|---|---|---|---|
| PostGIS GiST | 148 | 100 | 32% | **0.17ms** | GiST bbox scan + geography recheck |
| H3 res=9, grid_disk k=3 | 183 | 100 | 0% | 0.65ms | 37 cells、FP なし |
| zfxy z=19 | 142 | 100 | 30% | 0.37ms | 28×33 tile range |
| zfxy z=17 | 289 | 100 | 65% | 0.74ms | 8×9 tile range |
| zfxy z=15 | 982 | 100 | 90% | 10.6ms | 3×3 tile range（台東区全域 ≈ 9 タイル）|
| GeoHash prec=7 | ~25,833 | 85 | — | 6.6ms | LIKE prefix が seq scan にフォールバック |

**結論: GiST が最速。zfxy z=19 は H3 より速いが GiST には 2倍差がある。z=15 は台東区規模の dense urban では事実上無効（全件スキャン相当）。**

### zfxy resolution sweep（radius 1km、full scan、LIMIT なし）

| z | タイル幅 | 候補数 | 実数 | FP 率 |
|---|---|---|---|---|
| 15 | 3×3 | 16,670 | 10,755 | 35.5% |
| 16 | 5×5 | 16,102 | 10,755 | 33.2% |
| 17 | 8×9 | 13,938 | 10,630 | 23.7% |
| 18 | 15×17 | 12,907 | 10,616 | 17.8% |
| 19 | 28×33 | 11,803 | 10,327 | 12.5% |

FP 率は解像度を上げるほど改善するが、z=19 でも 12.5% 残る（タイルが正方形のため円とのズレが消えない）。

### 全クエリタイプ比較（zfxy z=15、JIT off、ウォーム）

| クエリ | 実行時間 | planner の選択 | 備考 |
|---|---|---|---|
| points / viewport | 0.5ms | GiST primary、zfxy は後フィルタ | GiST に完全制圧 |
| points / radius | 0.74ms（z=17）| zfxy tile range primary | 唯一 zfxy が主ドライバ |
| points / kNN | 0.6ms | GiST `<->` primary、zfxy 無視 | tile 拡張アプローチは使われない |
| polygons / viewport | 1.7ms | cover-first join | join 方向を誤ると 20秒（→後述）|
| polygons / PIP | 0.2ms | GiST primary（z=17）| zfxy は後フィルタ |

### polygon cover の注意点

- **join 方向の罠**: `polygon GiST → cover table` の順で書くと、台東区の場合 9,781ポリゴン × 19,027 cover行 = 1.86億行フィルタになり 20秒。`cover table → polygon` の順（cover-first）で 1.7ms。
- **bbox cover vs H3 polyfill**: zfxy の polygon cover は bbox タイルを全列挙するだけで、H3 `h3_polygon_to_cells` のような strict polygon cover ではない。台東区 z=15 では 1 タイルあたり最大 1,329件のポリゴンが候補になり、PIP の false positive は 266倍。
- **都市部での有効解像度**: z=15 は台東区全体が約 8タイルに収まるため B-tree filter が無効化される。z=17（~305m/tile）以上が実用最低ライン。

## 参考
- 実験の意図や比較観点は `TODO.md` に詳しく記載されています。
