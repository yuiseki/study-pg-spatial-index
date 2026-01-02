#!/usr/bin/env python
import json
import sys
from pathlib import Path


def _iter_geometries(obj):
    if obj.get("type") == "FeatureCollection":
        for feat in obj.get("features", []):
            geom = feat.get("geometry")
            if geom:
                yield geom
    elif obj.get("type") == "Feature":
        geom = obj.get("geometry")
        if geom:
            yield geom
    else:
        yield obj


def _iter_rings(geom):
    gtype = geom.get("type")
    coords = geom.get("coordinates")
    if not coords:
        return
    if gtype == "Polygon":
        yield from coords
    elif gtype == "MultiPolygon":
        for poly in coords:
            for ring in poly:
                yield ring
    else:
        raise ValueError(f"Unsupported geometry type: {gtype}")


def _is_hole(index: int) -> bool:
    return index > 0


def _write_ring(out, ring, label):
    if ring[0] != ring[-1]:
        ring = ring + [ring[0]]
    out.write(f"{label}\n")
    for lon, lat in ring:
        out.write(f"  {lon} {lat}\n")
    out.write("END\n")


def main():
    if len(sys.argv) < 3:
        print("Usage: geojson_to_poly.py <input.geojson> <output.poly> [name]", file=sys.stderr)
        raise SystemExit(2)

    in_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    name = sys.argv[3] if len(sys.argv) > 3 else in_path.stem

    data = json.loads(in_path.read_text())

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as out:
        out.write(f"{name}\n")
        ring_index = 1
        hole_index = 1
        for geom in _iter_geometries(data):
            rings = list(_iter_rings(geom))
            if not rings:
                continue
            for idx, ring in enumerate(rings):
                if _is_hole(idx):
                    _write_ring(out, ring, f"!{hole_index}")
                    hole_index += 1
                else:
                    _write_ring(out, ring, str(ring_index))
                    ring_index += 1
        out.write("END\n")


if __name__ == "__main__":
    main()
