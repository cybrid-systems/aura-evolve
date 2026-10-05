# aura-evolve

Aura Evolve is a live Soft world. One intersection — city approaches or two factory lines sharing a green — plus the strategy slots that race it, are a Soft FlatAST program. A thin C viewport, later, only blits frames. There is no C binary in this tree yet.

Design: [`docs/DESIGN.md`](docs/DESIGN.md).
Milestones: [`docs/m0.md`](docs/m0.md), [`docs/m1.md`](docs/m1.md), [`docs/m2.md`](docs/m2.md).
Repo: https://github.com/cybrid-systems/aura-evolve

This is not a traffic dashboard and not an Elo project. The product is the Aura loop: hot-strategy, worldline search, MutationBoundary, relower.

- **M0** races `strat-agg` and `strat-calm` host-sequential. It does not call `hot-strategy` or `fiber:spawn`. Stamp: `WORLD line=host-sequential joins=0/2`.
- **M1** swaps and heals the `ev:choose` slot mid-run, then races the same two bodies. `fiber_live` only when both fiber joins return scores. Otherwise `host-sequential`. See `docs/m1.md`.
- **M2** gates a proposed `(lambda (age own other) ...)` and KEEPs it only when its score is strictly greater than the current main. A tie or a loss is DROP plus `hot-strategy:heal!`. HTTP is host-side only.

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary `/workspace/aura-grok/build/aura`. Smoke always runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`. Never `build_soft4132`. Needs `AURA_SANDBOX=off`. `python3` is the host interpreter for `scripts/propose_minimax.py` and `scripts/burn.sh`.

```bash
bash scripts/smoke_soft.sh    # M0 → EVOLVE_M0_OK
bash scripts/smoke_m1.sh      # SWAP / HEAL / KEEP / DROP → EVOLVE_M1_OK
bash scripts/smoke_m2.sh      # fixture propose → EVOLVE_M2_PROPOSE_OK
bash scripts/smoke.sh         # the stack, plus live MiniMax or LIVE_SKIP
bash scripts/burn.sh          # 3 rounds, horizon 24; fixtures if EVOLVE_PROPOSE=0
```

Scripts may be mode `100644` in git. Always invoke them with `bash`.

`scripts/run_soft.sh` is the docker invocation. The source path is `$1`. It forwards `EVOLVE_HORIZON`, `EVOLVE_BURN_ROUNDS`, `EVOLVE_ROUND_DIR`, and `EVOLVE_PROPOSE_FILE`.

On seed `20261005`, 60 ticks, M0 keeps `strat-agg` (mid 1, score `-764`) and drops `strat-calm` (mid 2, score `-1086`). M1's race prints the same scores. On this binary that race is `WORLD line=fiber_live backend=2 joins=2/2` (`backend=2` is CLI thread fallback, not serve-async). M0's own stamp stays `host-sequential`.

M2's chase fixture (`other > own`) scores `-650` and is KEEP. The hold fixture scores `-2289` and is DROP. Fixture burn (horizon 24) KEEPs round 1 (`-193` vs agg `-241`) and DROPs a tie and a worse body. Detail in `docs/m2.md`.

## Engine

| Path | Role |
|------|------|
| `soft/evolve/world.aura` | intersection state, arrivals, service, score |
| `soft/evolve/strategy.aura` | `strat-agg` / `strat-calm`, M0 host-sequential race |
| `soft/evolve/hot.aura` | `ev:choose` / `ev:shadow`, swap, heal, honest fiber race |
| `soft/evolve/propose.aura` | gate a lambda file, race vs main, KEEP or DROP/heal |
| `soft/evolve/burn.aura` | multi-round propose → gate → play |
| `soft/evolve/m0_smoke.aura` | `EVOLVE_M0_OK` |
| `soft/evolve/m1_smoke.aura` | `EVOLVE_M1_OK` |
| `soft/evolve/m2_propose_smoke.aura` | fixture `EVOLVE_M2_PROPOSE_OK` |
| `soft/evolve/m2_live.aura` | one host lambda → `EVOLVE_M2_PROPOSE_LIVE_OK` |
| `scripts/propose_minimax.py` | MiniMax HTTP. No key in the tree. Default `https://api.minimax.cn/v1`. Never calls `api.minimaxi.com` |
| `scripts/burn.sh` | host rounds, then Soft |

KEEP on M2 requires a strictly higher score. M0's tie still keeps agg. At tick 24 every worldline does `(set! *stop-w* 3)` and prints `MUTATE`.

`python3 scripts/propose_minimax.py OUT [ROUND [NOTE [PREV]]]` reads `MINIMAX_API_KEY_FILE`, `MINIMAX_BASE_URL`, and `MINIMAX_MODEL` from `~/.config/aura-build/minimax.env`. Stderr is `PROPOSE_WROTE` or `PROPOSE_FAIL`. The key is never printed.

Soft is not Restricted mode. `fiber_live` is not printed unless the joins landed. M0 does not register a hot-strategy.

License: Apache-2.0

---

# aura-evolve（中文）

活世界在 Soft。M0 没有 fiber，印 `host-sequential`。M1 中途 `swap!` / `heal!`，只有两条 fiber 都 join 到分数时才印 `fiber_live`（这次是 `backend=2 joins=2/2`，线程回退，不是假装的调度器）。M2 由宿主脚本向 MiniMax 要策略，分数不比当前主策略高就 DROP 并 heal。密钥不进仓库，也不调用 `api.minimaxi.com`。

```bash
bash scripts/smoke.sh
bash scripts/burn.sh
```
