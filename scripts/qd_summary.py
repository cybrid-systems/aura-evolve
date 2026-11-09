#!/usr/bin/env python3
"""Summarise the 5-seed QD runs and apply the M2/M3 acceptance checks.

Usage: qd_summary.py OUT_DIR [M2_CHAMPION] [M3_CHAMPION]
Writes OUT_DIR/qd_summary.md and prints the same table to stdout.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

LINE = re.compile(r"QD_M(\d) evals=(\d+) elites=(\d+) coverage=(\d+) best=(-?\d+)")


def rows(out: Path, world: str) -> list[dict]:
    got = []
    for p in sorted(out.glob(f"qd_{world}_s*.txt")):
        seed = int(re.search(r"_s(\d+)\.txt$", p.name).group(1))
        m = LINE.search(p.read_text(encoding="utf-8", errors="replace"))
        if not m:
            got.append({"seed": seed, "ok": False})
            continue
        got.append({"seed": seed, "ok": True, "evals": int(m.group(2)),
                    "elites": int(m.group(3)), "coverage": int(m.group(4)),
                    "best": int(m.group(5))})
    return got


def table(title: str, rs: list[dict]) -> list[str]:
    lines = [f"### {title}", "", "| seed | evals | elites | coverage | best |",
             "|------|-------|--------|----------|------|"]
    for r in rs:
        if not r["ok"]:
            lines.append(f"| {r['seed']} | - | - | - | PARSE_FAIL |")
        else:
            lines.append(f"| {r['seed']} | {r['evals']} | {r['elites']} | "
                         f"{r['coverage']}% | {r['best']} |")
    lines.append("")
    return lines


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: qd_summary.py OUT_DIR [M2_CHAMPION] [M3_CHAMPION]", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    champ2 = int(sys.argv[2]) if len(sys.argv) > 2 else -650
    champ3 = int(sys.argv[3]) if len(sys.argv) > 3 else -1165
    m2, m3 = rows(out, "m2"), rows(out, "m3")
    body = ["# QD 5-seed summary", ""]
    body += table("M2 single intersection", m2)
    body += table("M3 corridor", m3)
    fails = 0
    for r in m2:
        if not r["ok"] or r["best"] < champ2:
            fails += 1
    for r in m3:
        if not r["ok"] or r["coverage"] < 60 or r["best"] < champ3:
            fails += 1
    body.append(f"M2 champion reference {champ2}; M3 champion reference {champ3}.")
    body.append(f"Checks: M2 best >= {champ2} and M3 coverage >= 60 and "
                f"M3 best >= {champ3}, for every seed.")
    body.append("")
    body.append("QD_SUMMARY_OK" if fails == 0 else f"QD_SUMMARY_FAIL ({fails})")
    body.append("")
    text = "\n".join(body)
    (out / "qd_summary.md").write_text(text, encoding="utf-8")
    print(text)
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

