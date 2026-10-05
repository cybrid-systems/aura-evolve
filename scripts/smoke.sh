#!/usr/bin/env bash
# Alias: M0 is the only smoke for now.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/scripts/smoke_soft.sh"
