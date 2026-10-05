#!/usr/bin/env bash
# M3 two-node grid + evolution tape. Does not replace M0/M1/M2.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/out"
echo "smoke: m3"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-evolve/soft/evolve/m3_smoke.aura \
  >"$ROOT/out/m3_smoke.txt" 2>"$ROOT/out/m3_smoke.err"
cat "$ROOT/out/m3_smoke.txt"
if [[ -s "$ROOT/out/m3_smoke.err" ]]; then
  cat "$ROOT/out/m3_smoke.err" >&2
fi
python3 "$ROOT/scripts/collect_tape.py" "$ROOT/out/m3_smoke.txt" "$ROOT/out/tape_m3.md" "M3 evolution tape"
fail=0
grep -q 'GRID nodes=2' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'POLICY mode=shared' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'POLICY mode=per-node' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'SWAP name=ev:choose' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'HEAL name=ev:choose' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'MUTATE tick=24 stop-w=3' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'KEEP mid=' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'DROP mid=' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'KEEP mid=3 reason=per-node-higher' "$ROOT/out/m3_smoke.txt" || fail=1
grep -q 'EVOLVE_M3_OK' "$ROOT/out/m3_smoke.txt" || fail=1
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/m3_smoke.txt" || fail=1
for op in RACE KEEP DROP SWAP HEAL MUTATE; do
  grep -q "ETAPE op=${op} " "$ROOT/out/m3_smoke.txt" || fail=1
done
if grep -q 'EVOLVE_M3_FAIL' "$ROOT/out/m3_smoke.txt"; then
  fail=1
fi
if grep -q 'WORLD line=fiber_live' "$ROOT/out/m3_smoke.txt"; then
  python3 - "$ROOT/out/m3_smoke.txt" << 'PY' || fail=1
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"WORLD line=fiber_live backend=(\d+) joins=(\d+)/(\d+)", text)
if not m or m.group(2) != m.group(3) or int(m.group(1)) <= 0 or int(m.group(2)) <= 0:
    sys.exit(1)
PY
fi
if grep -qiE 'error:|unbound variable' "$ROOT/out/m3_smoke.txt" "$ROOT/out/m3_smoke.err"; then
  fail=1
fi
if [[ ! -s "$ROOT/out/tape_m3.md" ]]; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "smoke_m3: EVOLVE_M3_OK checks failed" >&2
  exit 1
fi
echo "smoke_m3: EVOLVE_M3_OK"
