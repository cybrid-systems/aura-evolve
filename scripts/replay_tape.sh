#!/usr/bin/env bash
# Pretty-print the newest out/tape_*.md. No rewind engine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
shopt -s nullglob
files=("$ROOT"/out/tape_*.md)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "replay: no tape under out/tape_*.md"
  exit 0
fi
latest="$(ls -t "${files[@]}" | head -n 1)"
echo "replay: ${latest#"$ROOT"/}"
echo
cat "$latest"
