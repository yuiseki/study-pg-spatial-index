# TODO: PostgreSQLにおける様々な空間インデックスを比較（study-pg-spatial-index）

## ねらい
- 多様な空間インデックス／地理検索を実データで触り、 **何が得意で何が苦手か** を理解する
- 地理検索を「関数の使い方」ではなく、 **データ構造（インデックス／キー設計）** の観点で理解する
- 同じクエリセット・同じデータで比較し、 **比較の前提（モデル差）** も明記して整理する

## スコープ（重要）
今回の比較は **2系統を分けて評価** する。

### A. PostGISの「空間AM」（幾何列に対する空間インデックス）
- geometry/geography列に対して、GiST / SP-GiST / BRIN 等で候補抽出 → 厳密判定（recheck）

### B. DGGS／セルID設計（セルID列 + 通常インデックス）
- H3 / GeoHash / S2 / Q3C / HEALPix などで **セルID（整数/文字列）** を生成し、
  B-tree（主に）で候補抽出 → PostGIS等で厳密判定（recheck）
- ※「空間インデックス（AM）」そのものではなく **空間キー設計＋通常インデックス** の比較として扱う

## 今回はスキップ
- 点群（PointCloud）
- 時空間（MobilityDB など）

---

## データ（2系統）
### 1) Points / 2) Polygons: OSM（暫定）
- `osm2pgsql` default.style で `planet_osm_*` を生成して比較を先に進める
- 点: `planet_osm_point`、線/面: `planet_osm_line` / `planet_osm_polygon` を利用
- クリップは `osmium extract` + AOI poly を使用

### 予備（Overture Maps）
- 余力があれば GeoParquet から `places/buildings` を再構築する

#### データ取得メモ
- OSM: まず日本PBFから AOI 抽出（台東区など）
- OvertureはGeoParquet配布。公式: https://github.com/OvertureMaps/data
- 取得は「地理的範囲（AOI）」で絞って小さく始める（例: Tokyo bbox など）
- 再現性のため、使用した `RELEASE`（例: `YYYY-MM-DD.X`）と取得条件（AOI）を必ず記録する
- ライセンス／アトリビューション要件はテーマごとに異なる可能性があるので、公開時は要確認
  - 参照: https://docs.overturemaps.org/attribution/

---

## MVP: docker-composeで複数DBを立ち上げて比較

### 対象（MVP）
#### A. PostGIS（空間AM）
- PostGIS
  - GiST
  - SP-GiST
  - BRIN

#### B. DGGS／セルID設計（セルID + B-tree中心）
- H3（h3 / h3_postgis）
- S2（pgs2）
- GeoHash（pg_geohash / geohash-extra / 併せてPostGIS ST_GeoHashも利用可）
- Q3C（q3c）
- HEALPix（pg_healpix）

#### 追加（球面幾何の別系統）
- pgSphere（球面型 + GiST/BRIN）

---

## 比較の観点（指標）
### 1) インデックス構築
- 構築時間（wall time）
- インデックスサイズ（`pg_relation_size`）
- 統計（`ANALYZE`後のプラン差）

### 2) クエリ性能
- `EXPLAIN (ANALYZE, BUFFERS)` を基本（必要に応じて `WAL`, `SETTINGS`）
- cold / warm の両方で計測（DB再起動などで条件を揃える）
- 可能なら `pg_stat_statements` でクエリ統計も収集

### 3) “データ構造”の観察
- `pageinspect` を使ってページレベルで覗く（B-tree / GiST / BRIN など）
  - 例: btreeページ、gistページ、brinページの中身を観察し、木の形・分割・要約を理解する

---

## クエリセット（固定）
> 同一のSQL（または同一の意味の手順）を各方式で実行できるように、クエリを固定する

### Points（Places）
1. Viewport/BBox検索（地図の画面内）
   - 例: bbox内のPOI取得 + LIMIT
2. 半径検索（中心点 + 半径）
   - 例: `DWithin` 相当の検索（最後は距離でrecheck）
3. kNN（最寄りN件）
   - 例: 近い順にN件（PostGISは `<->` を使う）
   - DGGS系は「中心セル→近傍セルをリング拡張して候補集合を作る → 厳密距離でソートしてN件」を基本手順として統一

### Polygons（Buildings）
1. Viewport/BBox検索（bboxと交差する建物）
   - PostGIS: bbox演算子等で候補抽出 → `ST_Intersects` などでrecheck
   - DGGS: poly cover（被覆セル）で候補抽出 → `ST_Intersects` などでrecheck
2. Point-in-Polygon（点が含まれる建物）
   - PostGIS: `ST_Contains` 等
   - DGGS: 点のセルID→候補建物（coverテーブル）→ `ST_Contains` recheck

---

## 実装方針（暫定スキーマ）
### OSM（default.style）
- `planet_osm_point`
- `planet_osm_line`
- `planet_osm_polygon`
- `planet_osm_roads`

### DGGS用の“セル割り当て”テーブル（案）
#### places_cell（points）
- `place_id`, `cell_id`, `resolution`
- INDEX: (`resolution`, `cell_id`) B-tree

#### buildings_cell（polygons cover）
- `building_id`, `cell_id`, `resolution`
- INDEX: (`resolution`, `cell_id`) B-tree
- cover戦略（polyfillの精度・境界の漏れ）を明記し、recheck前提で設計する

---

## docker-compose（やること）
- [x] 各拡張ごとにサービスを分ける（同一Postgres versionで揃える）
- [x] init SQLで `CREATE EXTENSION ...` とスキーマ作成
- [x] データロード（同一AOI・同一件数）を自動化
- [x] インデックス作成（方式別にSQLを分離）
- [x] ベンチ用SQLを同一フォーマットで実行できるようにする

---

## 方式別の注釈（TODOに入れておくと親切）
- [x] H3: `h3` と `h3_postgis` が分かれているので、PostGIS連携関数が必要なら両方入れる
- [ ] pgs2: README上で Indexing がTODO扱いのため、MVPでは「S2Cell token（等）を列として保持→B-tree」で比較し、拡張自身の“空間AM”比較とは分ける
- [x] GeoHash: prefix検索で候補抽出できるが、クエリの書き方（前方一致等）でプランが変わるので注意。`geohash-extra` は近傍・geom→geohash群などをCで提供
- [ ] pg_geohash: `jistok/pg_geohash` は PostgreSQL 17 でビルドが通らないため、MVPでは見送り（必要なら別実装やパッチ検討）
- [x] Q3C: 基本は `q3c_ang2ipix(lon, lat)` の式インデックス（B-tree）で検索する設計
- [x] pg_healpix: ra/dec ↔ healpix ID 変換が中心。MVPでは「ID列＋B-tree」設計として扱う
- [x] pgSphere: 球面型（spoint等）向け。GiST（R-tree実装）に加えてBRINも対象にできる
- [ ] pageinspect: 低レベル観察に強いが、docker内ではsuperuser前提で実行する

---

## 計測・出力（成果物）
- [ ] 結果をCSV/JSONで保存（index build time / size / query time / buffers）
- [ ] クエリごとの `EXPLAIN (ANALYZE, BUFFERS)` を保存（差分が追える形）
- [ ] 結果サマリ（READMEに表・グラフ）
- [ ] “なぜそうなるか” をインデックス構造（pageinspect観察）と結びつけて説明

---

## 発展
- [ ] Deck.gl でセル（H3/GeoHash/S2/HEALPix/Q3C）可視化
- [ ] 解像度ごとの性能変化（resolution sweep）
- [ ] データ分布の違い（都市部 vs 郊外、密度差）で傾向がどう変わるか
