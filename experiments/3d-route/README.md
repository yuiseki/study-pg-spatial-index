# 3D-ish Route Benchmark

## 結論

zfxy の `f` 次元は、理屈の上では存在する。

しかし `f = floor(2^z * h / 2^25)` という式の構造上、
**水平解像度（x/y の細かさ）と垂直解像度（f の細かさ）を独立に設計できない。**
`z` を上げると x/y セルも一緒に細かくなり、
per-floor 粒度 (~3 m) を得るには z≥24 が必要だが、
そのとき x/y セルは赤道換算で ~1 m 角になる。

都市部のような密集エリアでは、現実的な zoom level（z=17–19）で
建物の 99% 以上が f=0 に収まってしまい、
3D セルテーブルは実質 2D と等価になる。

さらに、PostGIS GiST が利用可能な環境では
プランナーは常に geometry 列のインデックスを選択し、
zfxy B-tree の f/x/y 条件は Join Filter（後付けチェック）に格下げされる。

**「zfxy は 3D に見えるが、3D クエリキーとしてはかなり不器用。**
**PostGIS GiST + numeric height range が使える環境では、zfxy 3D B-tree に明確な競争優位はない。」**

zfxy が活きる可能性があるのは、GiST を持たない純 B-tree 環境
（外部キーバリューストア、列指向 DB、ファイルベース tile index など）に限られる。

---

既存の 2D zfxy / PostGIS / H3 / GeoHash / Q3C / HEALPix ベンチとは **独立した別系統** のベンチです。
既存の `common/bench/`・`systems/*/bench/`・`make bench-*` は変更していません。

## 目的

既存の zfxy 比較は `h=0` / `f=0` 固定の 2D-ish ベンチでした。

このベンチは「zfxy の `f` 次元（高さ方向）を導入したとき、普通の PostGIS GiST + 数値 height range と比べて何が変わるか」を冷静に測定します。

**zfxy を有利に見せることは目的ではありません。** `WHERE f BETWEEN ...` が本当に効くケースがあるかを実測します。

## データと設定

| 項目 | 値 |
|------|-----|
| データセット | OSM 台東区 |
| 建物数 | 36,521 |
| height タグあり | 34 件 |
| building:levels あり | 3,417 件 |
| デフォルト高さ | 15.0 m（未知建物ポリシー: `default_15m`） |
| median max_height_m | 15.0 m |
| max max_height_m | 129.16 m |
| zfxy 解像度 | z=19 |
| corridor | lon=139.785, lat 35.695→35.731, 幅 100 m |
| clearance | ±5 m |
| JIT | off |
| キャッシュ | warm |

## 高さモデル

`building_height_model` テーブル（`20_building_height_model.sql`）:

```
高さ推定優先順位:
  1. tags->'height'         (parse_height_m: "8", "10 m", "12.5", "30 ft" など対応)
  2. tags->'building:levels' * 3.0 m/floor
  3. default 15.0 m         (不明建物ポリシー: default_15m)
```

`parse_height_m()` は "10;12" の first-value 取り出しと ft→m 変換に対応。
parse 不能値は NULL に落とします。

## zfxy f 次元の粒度分析

zfxy の `f` は `floor(2^z * h / 2^25)` で計算されます。

| z | m/f-unit | f@30m | f@60m | f@90m | f@130m |
|---|----------|-------|-------|-------|--------|
| 17 | 256 m | 0 | 0 | 0 | 0 |
| 18 | 128 m | 0 | 0 | 0 | 1 |
| 19 | 64 m | 0 | 0 | 1 | 2 |
| 20 | 32 m | 0 | 1 | 2 | 4 |
| 21 | 16 m | 1 | 3 | 5 | 8 |
| 22 | 8 m | 3 | 7 | 11 | 16 |

**台東区での帰結:**
- z=17: 全建物が f=0（256 m/unit → 全建物 <256 m）
- z=18: 建物の 99.9% が f=0（128 m/unit、最高建物 ~129 m）
- z=19: 建物の 99.7% が f=0（64 m/unit、64 m 以上は 12 棟のみ）
- per-floor 粒度 (~3 m) には z≥24 が必要（2 m/unit）

## 3D セル分布（z=19）

| f | 建物数 | セル数 |
|---|--------|--------|
| 0 | 36,521 | 50,937 |
| 1 | 12 | 36 |
| 2 | 1 | 2 |

**50,975 セルのうち 50,937 (99.9%) が f=0。** 3D セルテーブルは実質 2D テーブルと等価。

## インデックスサイズ

| テーブル | データ | インデックス | 合計 |
|---------|--------|------------|------|
| planet_osm_polygon_zfxy (2D, z=15) | 11 MB | 8.8 MB | 20 MB |
| planet_osm_building_zfxy_3d (3D, z=19) | 12 MB | 4.9 MB | 16 MB |
| planet_osm_polygon | 9.2 MB | 2.6 MB | 12 MB |
| building_height_model (baseline) | 7.2 MB | 3.5 MB | 10 MB |

## corridor 候補数・実件数・FP 率

| alt (m) | height range | f_min | f_max | baseline_bbox_cands | baseline_actual | baseline_FP% | zfxy_cell_cands | zfxy_FP% |
|---------|-------------|-------|-------|---------------------|-----------------|--------------|-----------------|----------|
| 30 | 25–35 m | 0 | 0 | 1,884 | 16 | 99.2% | 3,183 | 99.5% |
| 60 | 55–65 m | 0 | 1 | 1,884 | 1 | 99.9% | 3,183 | 100.0% |
| 90 | 85–95 m | 1 | 1 | 1,884 | 0 | 100.0% | 1 | 100.0% |
| 120 | 115–125 m | 1 | 1 | 1,884 | 0 | 100.0% | 1 | 100.0% |

**alt=90m での観察:**
- zfxy: f=1 フィルタで 1 件のみ（12 棟のうち corridor x/y 範囲内は 1 棟）
- baseline: bbox 1,884 件をスキャン
- 実際には 85–95 m の建物はゼロ → 両方 FP=100%

## 実行時間（warm cache, JIT off）

| method | alt (m) | exec (ms) | shared_hits |
|--------|---------|-----------|-------------|
| baseline (GiST + height range) | 30 | 0.88 | 1,582 |
| baseline | 60 | 0.84 | 1,582 |
| baseline | 90 | 0.97 | 1,582 |
| baseline | 120 | 0.85 | 1,582 |
| zfxy_3d (z=19) | 30 | 1.58 | 3,346 |
| zfxy_3d (z=19) | 60 | 1.30 | 3,106 |
| zfxy_3d (z=19) | 90 | 1.47 | 3,086 |
| zfxy_3d (z=19) | 120 | 1.33 | 3,086 |

## クエリプランの観察（重要）

`zfxy_corridor.sql` を EXPLAIN すると、**プランナーは全ての altitude で GiST を選択し、zfxy B-tree を使いません。**

```
-> Nested Loop
     -> Seq Scan on route_corridor r
     -> Index Scan using building_height_model_geom_gist on building_height_model bhm
          Filter: (max_height_m >= ...) AND (min_height_m <= ...) AND st_intersects(...)
     -> Index Only Scan using planet_osm_building_zfxy_3d_pkey
          (Join Filter で f/x/y を後付けチェック)
```

プランナーは `building_height_model_geom_gist` の方が選択的と判断し、zfxy B-tree を index として採用しません。
f/x/y 条件は **Join Filter（後付けフィルタ）** として適用されるため、alt=90m でも全 corridor 建物を GiST スキャンします。

alt=60m の zfxy は shared_hits が 3,346 → 3,106 に減少（f=0,1 vs f=0 only）しますが、
alt=90m でも実行時間はほぼ同じ（GiST が全件スキャンするため）。

**結論: プランナーは GiST + height range の組み合わせを正しく選択しています。zfxy 3D B-tree は、PostGIS GiST が利用可能な環境では competitive advantage を持ちません。**

## zfxy 3D が意味を持ち得るケース

実測から導ける条件:

1. **PostGIS GiST が使えない環境**（純 B-tree 環境、あるいは geometry 列が存在しない）では、zfxy x/y/f cell range が代替になる
2. **z≥21 かつ建物密度が低い**ケース: f 次元で 16 m/unit の粒度が得られる
3. **高い建物 (≥128 m) が多いエリア**では f=2+ の区別が可能になるが、台東区データでは 1 棟のみ
4. **corridor が広い・y/x スパンが大きい**場合に、f フィルタで x/y スキャン量を削れる可能性はある（ただし今回は実測で確認できず）

## ディレクトリ構成

```
experiments/3d-route/
  README.md          ← このファイル
  sql/
    10_parse_height.sql           OSM height タグ parse 関数
    20_building_height_model.sql  建物高さモデル table
    30_route_corridor.sql         corridor 定義 table
    40_zfxy_3d_cells.sql          3D zfxy cell table (f 展開)
    50_baseline_indexes.sql       GiST + height range インデックス
  bench/
    baseline_corridor.sql         PostGIS GiST + height range
    zfxy_corridor.sql             zfxy 3D B-tree + recheck
  scripts/
    run_3d_route_bench.sh         フルベンチ実行スクリプト
    summarize_results.py          EXPLAIN 結果から summary 生成
```

## 実行方法

```bash
# zfxy コンテナ (port 55442) に対してフルベンチ実行
make bench3d-route

# または直接
PGPORT=55442 PGPASSWORD=postgres experiments/3d-route/scripts/run_3d_route_bench.sh
```

結果は `results/3d-route/<timestamp>/` に保存されます。

## 制約と注意点

- corridor は bbox 矩形近似であり、swept-circle や true offset polygon ではありません
- bbox cover であるため corridor 端部の FP は必然です（recheck 必須）
- zfxy 3D cover は H3 polyfill や S2 covering のような strict polygon cover ではありません
- Stage 2（グリッド経路探索、A*/Dijkstra）は未実装です（このファイルは Stage 1 の記録）
