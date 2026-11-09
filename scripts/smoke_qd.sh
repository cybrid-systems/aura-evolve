#!/usr/bin/env bash
# M2/M3 acceptance for #4946: MAP-Elites replaces "strictly greater" in M2,
# the M3 corridor must reach >= 60% coverage and a best elite no worse than
# the old champion, and the ETAPE tape must be generated from the evo log and
# agree with the aura evo log/report view.
#
#   AURA_PATH=/path/to/aura/lib bash scripts/smoke_qd.sh
#
# Runs offline on synthetic data only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
AURA_BIN="${AURA_BIN:-/home/dev/code/aura-wt-v020-qd-dx/build/aura}"
SEEDS="${EVOLVE_QD_SEEDS:-1 2 3 4 5}"
M2_CHAMPION="${EVOLVE_M2_CHAMPION:--650}"
M3_CHAMPION="${EVOLVE_M3_CHAMPION:--1165}"
mkdir -p "$OUT"

soft() { bash "$ROOT/scripts/run_soft.sh" "$1"; }

echo "qd: baseline (legacy single-champion M2 / M3)"
bash "$ROOT/scripts/smoke_m2.sh" >"$OUT/qd_baseline_m2.log" 2>&1 || {
  cat "$OUT/qd_baseline_m2.log" >&2; exit 1; }
bash "$ROOT/scripts/smoke_m3.sh" >"$OUT/qd_baseline_m3.log" 2>&1 || {
  cat "$OUT/qd_baseline_m3.log" >&2; exit 1; }
grep -q 'EVOLVE_M2_PROPOSE_OK' "$OUT/qd_baseline_m2.log"
grep -q 'EVOLVE_M3_OK' "$OUT/qd_baseline_m3.log"

echo "qd: seeds (search seed only; the sim seed stays 20261005)"
for s in $SEEDS; do
  # The evo log is append-only and AURA_EVO_RUN repeats per seed, so a stale
  # file would make the same run id appear twice. Start each seed clean.
  rm -f "$OUT/evo_m2_s$s.jsonl" "$OUT/evo_m3_s$s.jsonl"
  AURA_EVO_LOG="$OUT/evo_m2_s$s.jsonl" AURA_EVO_RUN="m2-s$s" EVOLVE_QD_SEED="$s" \
    soft /workspace/aura-evolve/soft/evolve/qd_m2.aura >"$OUT/qd_m2_s$s.txt" 2>&1 || {
      tail -5 "$OUT/qd_m2_s$s.txt" >&2; exit 1; }
  AURA_EVO_LOG="$OUT/evo_m3_s$s.jsonl" AURA_EVO_RUN="m3-s$s" EVOLVE_QD_SEED="$s" \
    soft /workspace/aura-evolve/soft/evolve/qd_m3.aura >"$OUT/qd_m3_s$s.txt" 2>&1 || {
      tail -5 "$OUT/qd_m3_s$s.txt" >&2; exit 1; }
  echo "  seed $s: $(grep -h -E '^QD_M[23] ' "$OUT/qd_m2_s$s.txt" "$OUT/qd_m3_s$s.txt" | tr '\n' ' ')"
done

python3 "$ROOT/scripts/qd_summary.py" "$OUT" "$M2_CHAMPION" "$M3_CHAMPION"

# Fixed seed 1: tape from the log, report from the same log, then the
# cross-check between them.
for w in m2 m3; do
  run="m${w#m}-s1"
  log="$OUT/evo_${w}_s1.jsonl"
  "$AURA_BIN" evo report --html "$OUT/report_$w" --log "$log" --run "$run" \
    >"$OUT/report_${w}.log" 2>&1
  python3 "$ROOT/scripts/tape_from_evo_log.py" "$log" "$run" "$OUT/tape_${w}_qd.txt"
  python3 "$ROOT/scripts/collect_tape.py" "$OUT/tape_${w}_qd.txt" \
    "$OUT/tape_${w}_qd.md" "M${w#m} QD evolution tape"
  python3 "$ROOT/scripts/verify_evo_tape.py" "$log" "$run" \
    "$OUT/tape_${w}_qd.txt" "$OUT/qd_${w}_s1.txt" "$AURA_BIN" "$OUT/report_$w"
done

grep -q 'EVOLVE_QD_M2_OK' "$OUT/qd_m2_s1.txt"
grep -q 'EVOLVE_QD_M3_OK' "$OUT/qd_m3_s1.txt"
echo "smoke_qd: EVOLVE_QD_OK"

