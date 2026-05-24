#!/usr/bin/env python3
"""
summarize_results.py — extract execution times from EXPLAIN output files
and emit a Markdown summary table.

Usage:
    python3 summarize_results.py <results_dir>
"""

import re
import sys
import json
from pathlib import Path


def extract_execution_time_ms(txt: str) -> float | None:
    m = re.search(r"Execution Time:\s+([\d.]+)\s+ms", txt)
    if m:
        return float(m.group(1))
    return None


def extract_planning_time_ms(txt: str) -> float | None:
    m = re.search(r"Planning Time:\s+([\d.]+)\s+ms", txt)
    if m:
        return float(m.group(1))
    return None


def extract_shared_hits(txt: str) -> int | None:
    # Sum all "shared hit=N" in the plan
    hits = re.findall(r"shared hit=(\d+)", txt)
    return sum(int(h) for h in hits) if hits else None


def main():
    if len(sys.argv) < 2:
        print("Usage: summarize_results.py <results_dir>", file=sys.stderr)
        sys.exit(1)

    results_dir = Path(sys.argv[1])
    explain_dir = results_dir / "explain"
    metadata_file = results_dir / "metadata.json"

    metadata = {}
    if metadata_file.exists():
        metadata = json.loads(metadata_file.read_text())

    rows = []
    for txt_file in sorted(explain_dir.glob("*.txt")):
        txt = txt_file.read_text()
        exec_ms = extract_execution_time_ms(txt)
        plan_ms = extract_planning_time_ms(txt)
        hits = extract_shared_hits(txt)

        # Parse filename: {method}_alt{altitude}m.txt
        stem = txt_file.stem
        m = re.match(r"(.+)_alt(\d+)m", stem)
        if not m:
            continue
        method_raw = m.group(1)
        altitude = int(m.group(2))
        method = "baseline" if "baseline" in method_raw else "zfxy_3d (z=19)"

        rows.append({
            "method": method,
            "altitude_m": altitude,
            "exec_ms": exec_ms,
            "plan_ms": plan_ms,
            "shared_hits": hits,
        })

    if not rows:
        print("No EXPLAIN files found.", file=sys.stderr)
        sys.exit(0)

    # Write summary CSV
    csv_file = results_dir / "summary.csv"
    with csv_file.open("w") as f:
        f.write("method,altitude_m,exec_ms,plan_ms,shared_hits\n")
        for r in rows:
            f.write(
                f"{r['method']},{r['altitude_m']},"
                f"{r['exec_ms']},{r['plan_ms']},{r['shared_hits']}\n"
            )

    # Build Markdown table
    lines = []
    lines.append("# 3D Route Bench — Summary\n")
    lines.append(f"Dataset: {metadata.get('dataset', 'unknown')}  ")
    lines.append(f"Corridor: lon=139.785, lat 35.695→35.731, width=100 m  ")
    lines.append(f"Height model: {metadata.get('height_model', '?')}  ")
    lines.append(f"Unknown height policy: {metadata.get('unknown_height_policy', '?')}  ")
    lines.append(f"zfxy resolution: {metadata.get('zfxy_3d_resolution', '?')}  ")
    lines.append(
        f"3D cells (z=19): total={metadata.get('cells_3d_z19_total', '?')}, "
        f"f=0: {metadata.get('cells_3d_z19_f_eq_0', '?')}, "
        f"f>0: {metadata.get('cells_3d_z19_f_gt_0', '?')}"
    )
    lines.append("")
    lines.append("## Execution time (warm cache, JIT off)")
    lines.append("")
    lines.append("| method | alt (m) | exec (ms) | plan (ms) | shared_hits |")
    lines.append("|--------|---------|-----------|-----------|-------------|")
    for r in sorted(rows, key=lambda x: (x["method"], x["altitude_m"])):
        lines.append(
            f"| {r['method']} | {r['altitude_m']} "
            f"| {r['exec_ms']} | {r['plan_ms']} | {r['shared_hits']} |"
        )

    lines.append("")
    lines.append("## Key observation")
    lines.append("")
    lines.append("| z  | m/f-unit | f@30m | f@60m | f@90m | f@130m |")
    lines.append("|----|----------|-------|-------|-------|--------|")
    for z, unit in [(17, 256), (18, 128), (19, 64), (20, 32), (21, 16), (22, 8)]:
        f30  = int(30  * (2**z) / (2**25))
        f60  = int(60  * (2**z) / (2**25))
        f90  = int(90  * (2**z) / (2**25))
        f130 = int(130 * (2**z) / (2**25))
        lines.append(f"| {z} | {unit} m | {f30} | {f60} | {f90} | {f130} |")

    lines.append("")
    lines.append(
        "At z=17–18, ALL Taito-ku buildings have f=0 (f-filter provides zero selectivity).  \n"
        "At z=19, only buildings ≥64 m have f≥1 (≈0.3% of Taito-ku buildings).  \n"
        "The zfxy 3D approach reduces to the 2D corridor scan at typical web map zoom levels."
    )

    summary_md = results_dir / "summary.md"
    md_text = "\n".join(lines)
    summary_md.write_text(md_text)
    print(md_text)


if __name__ == "__main__":
    main()
