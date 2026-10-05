#!/usr/bin/env python3
"""Build out/pk_scoreboard.md from PK lines. Does not invent fiber_live."""
from __future__ import annotations

import re
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) < 3:
        print("scoreboard: usage", file=sys.stderr)
        return 2
    src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    out = Path(sys.argv[2])
    rows = re.findall(
        r"^PK round=(\d+) tag=(\S+) base=(\S+) trial=(\S+) main=(\S+)\s*$",
        src,
        re.M,
    )
    world = re.search(r"^WORLD line=.*$", src, re.M)
    base = re.search(r"^BASELINE policy=(\S+) score=(\S+)\s*$", src, re.M)
    lines = [
        "# PK scoreboard",
        "",
        "Two-node corridor. Shared policy per round. Score is throughput − queue − stop.",
        "KEEP only when trial > base. A tie is DROP.",
        "",
    ]
    if base:
        lines.append(f"Baseline `{base.group(1)}` score `{base.group(2)}`.")
        lines.append("")
    lines.append("| round | tag | base | trial | main |")
    lines.append("|------:|-----|-----:|------:|-----:|")
    for rnd, tag, b, trial, main_s in rows:
        lines.append(f"| {rnd} | {tag} | {b} | {trial} | {main_s} |")
    lines.append("")
    if world:
        lines.append("World line copied from Soft (not invented here):")
        lines.append("")
        lines.append("```")
        lines.append(world.group(0))
        lines.append("```")
    else:
        lines.append("World line: missing")
    lines.append("")
    lines.append(f"rounds: {len(rows)}")
    lines.append("")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"SCOREBOARD_WROTE {out} rounds={len(rows)}")
    return 0 if rows else 1

if __name__ == "__main__":
    sys.exit(main())
