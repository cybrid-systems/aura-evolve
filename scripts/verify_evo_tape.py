#!/usr/bin/env python3
"""Check that the ETAPE tape and the aura evo log/report agree.

Usage: verify_evo_tape.py LOG RUN TAPE_TXT SOFT_OUT AURA_BIN REPORT_DIR

Checks (each prints one line):
  FRONT_SUBSET     every non-dominated record the CLI reports is a KEEP row
  LINEAGE_MATCH    the ancestor chain of the best elite is in the tape, in order
  BEST_MATCH       the tape's best KEEP score equals the Soft QD_Mx "best="
  COVERAGE_MATCH   the CLI-visible coverage evidence equals the Soft "coverage="
  REPORT_ARTIFACTS index.html + qd-heatmap.svg + lineage.svg exist
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


def cli(bin_path: str, args: list[str]) -> str:
    return subprocess.run([bin_path, *args], capture_output=True, text=True, check=True).stdout


def main() -> int:
    if len(sys.argv) not in (6, 7):
        print("usage: verify_evo_tape.py LOG RUN TAPE SOFT_OUT AURA_BIN [REPORT_DIR]", file=sys.stderr)
        return 2
    log, run, tape, soft, aura = map(str, sys.argv[1:6])
    report = Path(sys.argv[6]) if len(sys.argv) > 6 else None
    fails = 0

    tape_rows = []
    for line in Path(tape).read_text(encoding="utf-8").splitlines():
        m = re.match(r"^ETAPE op=(\S+) tick=(\S+) mid=(\S+) score=(\S+) reason=(.*)$", line)
        if m:
            tape_rows.append(
                {"op": m.group(1), "score": int(m.group(4)),
                 "reason": m.group(5),
                 "id": "#" + re.search(r"id=#(\d+)", m.group(5)).group(1)}
            )
    tape_keep = {r["id"] for r in tape_rows if r["op"] == "KEEP"}

    front = json.loads(cli(aura, ["evo", "log", "--log", log, "--run", run,
                                  "--front", "--json"]) or "[]")
    front_ids = {"#" + r["id"].rsplit("#", 1)[-1] for r in front}
    ok = front_ids <= tape_keep
    print(f"FRONT_SUBSET {'OK' if ok else 'FAIL'} front={len(front_ids)} "
          f"missing={sorted(front_ids - tape_keep)}")
    fails += 0 if ok else 1

    best = max(front, key=lambda r: r["evidence"]["score"]) if front else None
    if best is None:
        print("LINEAGE_MATCH FAIL no front")
        fails += 1
    else:
        chain = json.loads(cli(aura, ["evo", "log", "--log", log, "--run", run,
                                      "--lineage", best["id"], "--json"]) or "[]")
        chain_ids = ["#" + r["id"].rsplit("#", 1)[-1] for r in chain]
        ok = bool(chain_ids) and set(chain_ids) <= tape_keep and chain_ids[-1] == "#" + best["id"].rsplit("#", 1)[-1]
        print(f"LINEAGE_MATCH {'OK' if ok else 'FAIL'} chain={chain_ids}")
        fails += 0 if ok else 1

    soft_text = Path(soft).read_text(encoding="utf-8", errors="replace")
    m = re.search(r"QD_M\d\b.*?\bbest=(-?\d+)", soft_text)
    tape_best = max((r["score"] for r in tape_rows if r["op"] == "KEEP"), default=None)
    ok = m is not None and tape_best is not None and int(m.group(1)) == tape_best
    print(f"BEST_MATCH {'OK' if ok else 'FAIL'} soft={m.group(1) if m else '?'} tape={tape_best}")
    fails += 0 if ok else 1

    mc = re.search(r"coverage=(\d+)", soft_text)
    covs = [int(c) for c in re.findall(r"cov=(\d+)", Path(tape).read_text())]
    ok = mc is not None and covs and max(covs) == int(mc.group(1))
    print(f"COVERAGE_MATCH {'OK' if ok else 'FAIL'} soft={mc.group(1) if mc else '?'} tape_max={max(covs) if covs else '?'}")
    fails += 0 if ok else 1

    if report:
        need = ["index.html", "qd-heatmap.svg", "lineage.svg"]
        ok = all((report / n).exists() for n in need)
        print(f"REPORT_ARTIFACTS {'OK' if ok else 'FAIL'} {report}")
        fails += 0 if ok else 1

    print("VERIFY_OK" if fails == 0 else "VERIFY_FAIL")
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

