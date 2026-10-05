#!/usr/bin/env bash
# Sustained PK on the two-node grid. Default 4 rounds, horizon 24.
# EVOLVE_PROPOSE=1 calls MiniMax when a key file exists; otherwise fixtures.
# EVOLVE_PROPOSE=0 always uses soft/evolve/fixtures/pk (offline).
# Writes out/pk_scoreboard.md and out/tape_pk.md.
# Run: bash scripts/burn_pk.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export EVOLVE_BURN_ROUNDS="${EVOLVE_PK_ROUNDS:-${EVOLVE_BURN_ROUNDS:-4}}"
export EVOLVE_HORIZON="${EVOLVE_HORIZON:-24}"
export EVOLVE_PROPOSE="${EVOLVE_PROPOSE:-1}"
mkdir -p "$ROOT/out"
keyfile="/home/box/.config/aura-build/minimax_api_key"

if [[ "$EVOLVE_PROPOSE" == "1" && -s "$keyfile" ]]; then
  dir="$ROOT/out/pk-rounds"
  rm -rf "$dir"
  mkdir -p "$dir"
  prev=""
  note="grid shared policy, two intersections, beat the current main"
  for ((r=1; r<=EVOLVE_BURN_ROUNDS; r++)); do
    out="$dir/${r}.lambda"
    echo "pk: propose round ${r}"
    if [[ -n "$prev" ]]; then
      python3 "$ROOT/scripts/propose_minimax.py" "$out" "$r" "$note" "$prev" \
        >/tmp/evolve-pk-propose.stdout 2>"$ROOT/out/pk_propose_${r}.stderr"
    else
      python3 "$ROOT/scripts/propose_minimax.py" "$out" "$r" "$note" \
        >/tmp/evolve-pk-propose.stdout 2>"$ROOT/out/pk_propose_${r}.stderr"
    fi
    cat "$ROOT/out/pk_propose_${r}.stderr" >&2 || true
    test -s "$out"
    echo "pk: round ${r} $(tr -d '\n' < "$out")"
    prev="$out"
    note="round ${r} wrote a lambda; grid score must strictly improve"
  done
  export EVOLVE_ROUND_DIR="/workspace/aura-evolve/out/pk-rounds"
else
  if [[ "$EVOLVE_PROPOSE" == "1" ]]; then
    echo "pk: no MiniMax key; fixture rounds" >&2
  else
    echo "pk: fixture rounds"
  fi
  export EVOLVE_ROUND_DIR="/workspace/aura-evolve/soft/evolve/fixtures/pk"
fi

echo "pk: rounds=${EVOLVE_BURN_ROUNDS} horizon=${EVOLVE_HORIZON} dir=${EVOLVE_ROUND_DIR}"
bash "$ROOT/scripts/run_soft.sh" /workspace/aura-evolve/soft/evolve/pk.aura \
  >"$ROOT/out/pk.txt" 2>"$ROOT/out/pk.err"
cat "$ROOT/out/pk.txt"
if [[ -s "$ROOT/out/pk.err" ]]; then
  cat "$ROOT/out/pk.err" >&2
fi
python3 "$ROOT/scripts/scoreboard.py" "$ROOT/out/pk.txt" "$ROOT/out/pk_scoreboard.md"
python3 "$ROOT/scripts/collect_tape.py" "$ROOT/out/pk.txt" "$ROOT/out/tape_pk.md" "PK evolution tape"
fail=0
grep -q 'EVOLVE_PK_OK' "$ROOT/out/pk.txt" || fail=1
grep -E -q 'WORLD line=(host-sequential|fiber_live)' "$ROOT/out/pk.txt" || fail=1
grep -q 'PK round=' "$ROOT/out/pk.txt" || fail=1
if [[ "$EVOLVE_PROPOSE" == "0" ]]; then
  grep -q 'KEEP reason=higher-score-stamp' "$ROOT/out/pk.txt" || fail=1
  grep -q 'DROP reason=lower-score-rollback' "$ROOT/out/pk.txt" || fail=1
fi
if grep -q 'EVOLVE_PK_FAIL' "$ROOT/out/pk.txt"; then
  fail=1
fi
if grep -q 'WORLD line=fiber_live' "$ROOT/out/pk.txt"; then
  python3 - "$ROOT/out/pk.txt" << 'PY' || fail=1
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"WORLD line=fiber_live backend=(\d+) joins=(\d+)/(\d+)", text)
if not m or m.group(2) != m.group(3) or int(m.group(1)) <= 0 or int(m.group(2)) <= 0:
    sys.exit(1)
PY
fi
if grep -qiE 'error:|unbound variable' "$ROOT/out/pk.txt" "$ROOT/out/pk.err"; then
  fail=1
fi
if [[ ! -s "$ROOT/out/pk_scoreboard.md" || ! -s "$ROOT/out/tape_pk.md" ]]; then
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "burn_pk: EVOLVE_PK_OK checks failed" >&2
  exit 1
fi
echo "burn_pk: EVOLVE_PK_OK"
