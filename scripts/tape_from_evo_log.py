#!/usr/bin/env python3
"""Turn an AURA_EVO_LOG run into ETAPE lines (the evolution tape).

Usage: tape_from_evo_log.py LOG RUN OUT_TXT

The log is the only source. No Soft stdout is parsed, so the tape and
`aura evo log` cannot disagree about what happened.
ETAPE op=KEEP|DROP|SWAP|HEAL|MUTATE tick=<gen> mid=<slot> score=<n> reason=<free>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def short(rec_id: str) -> str:
    return "#" + rec_id.rsplit("#", 1)[-1]


def main() -> int:
    if len(sys.argv) != 4:
        print("tape_from_evo_log: usage LOG RUN OUT_TXT", file=sys.stderr)
        return 2
    log, run, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    rows: list[str] = []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if r.get("run") != run or r.get("kind") != "record":
            continue
        decision = r.get("decision", "")
        if decision == "KEEP":
            op = "KEEP"
        elif decision in ("SWAP", "HEAL", "MUTATE"):
            op = decision
        else:
            op = "DROP"
        ev = r.get("evidence") if isinstance(r.get("evidence"), dict) else {}
        score = ev.get("score", 0)
        gen = r.get("gen", 0)
        slot = r.get("slot", 0)
        reason = r.get("reason", "") or "-"
        bits = [reason.replace(" ", "_"), f"id={short(r.get('id', ''))}"]
        if "coverage" in ev:
            bits.append(f"cov={int(round(100 * float(ev['coverage'])))}")
        rows.append(
            f"ETAPE op={op} tick={gen} mid={slot} score={int(score)} "
            f"reason={' '.join(bits)}"
        )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(rows) + ("\n" if rows else ""), encoding="utf-8")
    print(f"TAPE_WROTE {out} events={len(rows)}")
    return 0 if rows else 1


if __name__ == "__main__":
    sys.exit(main())

