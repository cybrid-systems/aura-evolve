#!/usr/bin/env python3
"""Turn Soft ETAPE lines into an append-ordered markdown tape.

Usage: collect_tape.py SRC_TXT OUT_MD TITLE
The output is a new file for this run. Rows follow emit order and are not rewritten.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) < 3:
        print("collect_tape: usage", file=sys.stderr)
        return 2
    src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    out = Path(sys.argv[2])
    title = sys.argv[3] if len(sys.argv) > 3 else "evolution tape"
    pat = re.compile(
        r"^ETAPE op=(\S+) tick=(\S+) mid=(\S+) score=(\S+) reason=(.*)$",
        re.M,
    )
    rows = pat.findall(src)
    lines = [
        f"# {title}",
        "",
        "Append-only log of Soft `ETAPE` lines, in emit order.",
        "This file is a pretty view of that log. It is not a rewind engine.",
        "",
        "| # | op | tick | mid | score | reason |",
        "|---|----|------|-----|-------|--------|",
    ]
    for i, (op, tick, mid, score, reason) in enumerate(rows, 1):
        reason = reason.replace("|", "/")
        lines.append(f"| {i} | {op} | {tick} | {mid} | {score} | {reason} |")
    lines.append("")
    lines.append(f"events: {len(rows)}")
    lines.append("")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"TAPE_WROTE {out} events={len(rows)}")
    return 0 if rows else 1

if __name__ == "__main__":
    sys.exit(main())
