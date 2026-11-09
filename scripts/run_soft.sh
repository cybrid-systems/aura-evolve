#!/usr/bin/env bash
# Shared Soft runner: tip aura inside ghcr.io/cybrid-systems/dev:v1.0.9.
# Soft runs natively in the container (no nested docker). Never build_soft4132.
# Offline hosts without docker (or with EVOLVE_RUNNER=local) use a native
# aura binary instead: AURA_BIN (default: /home/dev/code/aura-wt-v020-qd-dx/build/aura)
# with AURA_PATH pointing at that tree's lib. The Soft sources are unchanged.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AURA_SRC="${AURA_SRC:-/workspace/aura-grok}"
IMG="ghcr.io/cybrid-systems/dev:v1.0.9"
SRC="${1:?aura source path}"
shift || true

run_local() {
  : "${AURA_PATH:?local runner needs AURA_PATH=<aura tree>/lib}"
  local bin="${AURA_BIN:-/home/dev/code/aura-wt-v020-qd-dx/build/aura}"
  if [[ ! -x "$bin" ]]; then
    echo "run_soft: no aura binary at $bin" >&2
    exit 1
  fi
  if [[ ! -e /workspace/aura-evolve ]]; then
    echo "run_soft: local runner needs /workspace/aura-evolve -> $ROOT" >&2
    exit 1
  fi
  exec env AURA_PATH="$AURA_PATH" \
    AURA_SANDBOX="${AURA_SANDBOX:-off}" \
    AURA_PIPELINE_STRICT="${AURA_PIPELINE_STRICT:-0}" \
    EVOLVE_HORIZON="${EVOLVE_HORIZON:-}" \
    EVOLVE_BURN_ROUNDS="${EVOLVE_BURN_ROUNDS:-}" \
    EVOLVE_ROUND_DIR="${EVOLVE_ROUND_DIR:-}" \
    EVOLVE_PROPOSE_FILE="${EVOLVE_PROPOSE_FILE:-}" \
    EVOLVE_PROPOSE="${EVOLVE_PROPOSE:-}" \
    EVOLVE_QD_SEED="${EVOLVE_QD_SEED:-}" \
    EVOLVE_QD_BUDGET="${EVOLVE_QD_BUDGET:-}" \
    EVOLVE_QD_FLOOR="${EVOLVE_QD_FLOOR:-}" \
    AURA_EVO_LOG="${AURA_EVO_LOG:-}" \
    AURA_EVO_RUN="${AURA_EVO_RUN:-}" \
    "$bin" "$SRC" "$@"
}

if [[ "${EVOLVE_RUNNER:-docker}" == "local" ]]; then
  run_local
fi

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "run_soft: docker not available; falling back to the native aura binary" >&2
  run_local
fi

exec "${DOCKER[@]}" run --rm -i --entrypoint /usr/local/bin/gosu \
  -v "${AURA_SRC}:/workspace/aura-grok" \
  -v "${ROOT}:/workspace/aura-evolve" \
  -w /workspace/aura-evolve \
  -e AURA_PATH=/workspace/aura-grok/lib \
  -e AURA_PIPELINE_STRICT=0 \
  -e AURA_SANDBOX=off \
  -e AURA_BIN=/workspace/aura-grok/build/aura \
  -e "EVOLVE_HORIZON=${EVOLVE_HORIZON:-}" \
  -e "EVOLVE_BURN_ROUNDS=${EVOLVE_BURN_ROUNDS:-}" \
  -e "EVOLVE_ROUND_DIR=${EVOLVE_ROUND_DIR:-}" \
  -e "EVOLVE_PROPOSE_FILE=${EVOLVE_PROPOSE_FILE:-}" \
  -e "EVOLVE_PROPOSE=${EVOLVE_PROPOSE:-}" \
  -e "EVOLVE_QD_SEED=${EVOLVE_QD_SEED:-}" \
  -e "EVOLVE_QD_BUDGET=${EVOLVE_QD_BUDGET:-}" \
  -e "EVOLVE_QD_FLOOR=${EVOLVE_QD_FLOOR:-}" \
  -e "AURA_EVO_LOG=${AURA_EVO_LOG:-}" \
  -e "AURA_EVO_RUN=${AURA_EVO_RUN:-}" \
  "${IMG}" \
  dev /usr/bin/stdbuf -oL -eL /workspace/aura-grok/build/aura "$SRC" "$@"
