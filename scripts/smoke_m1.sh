#!/usr/bin/env bash
# M1 hot-strategy + honest worldline. Does not replace M0.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"
echo "smoke: m1"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-evolve/soft/evolve/m1_smoke.aura \
  >"$ROOT/out/m1_smoke.txt" 2>"$ROOT/out/m1_smoke.err"
cat "$ROOT/out/m1_smoke.txt"
if [[ -s "$ROOT/out/m1_smoke.err" ]]; then
  cat "$ROOT/out/m1_smoke.err" >&2
fi
fail=0
grep -q 'SWAP name=ev:choose' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'HEAL name=ev:choose' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'MUTATE tick=24 stop-w=3' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'KEEP mid=' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'DROP mid=' "$ROOT/out/m1_smoke.txt" || fail=1
grep -q 'EVOLVE_M1_OK' "$ROOT/out/m1_smoke.txt" || fail=1
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/m1_smoke.txt" || fail=1
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m1_smoke.txt"; then
  grep -E -q 'backend=[1-9][0-9]* joins=[1-9][0-9]*/[1-9][0-9]*' "$ROOT/out/m1_smoke.txt" || fail=1
  # joined count must equal spawned count
  python3 - "$ROOT/out/m1_smoke.txt" << 'PY' || fail=1
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"WORLD line=fiber_live backend=(\d+) joins=(\d+)/(\d+)", text)
if not m or m.group(2) != m.group(3) or int(m.group(1)) <= 0 or int(m.group(2)) <= 0:
    sys.exit(1)
PY
fi
if grep -q 'EVOLVE_M1_FAIL' "$ROOT/out/m1_smoke.txt"; then
  fail=1
fi
if grep -qiE 'error:|unbound variable' "$ROOT/out/m1_smoke.txt" "$ROOT/out/m1_smoke.err"; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "smoke_m1: EVOLVE_M1_OK checks failed" >&2
  exit 1
fi
echo "smoke_m1: EVOLVE_M1_OK"
