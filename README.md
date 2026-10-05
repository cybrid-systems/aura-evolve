# aura-evolve

Aura Evolve is a live Soft world. One intersection — city approaches or two
factory lines sharing a green — plus the strategy slots that race it, are a
Soft FlatAST program. A thin C viewport, later, only blits frames. There is
no C binary in this tree yet.

Design: [`docs/DESIGN.md`](docs/DESIGN.md).
Milestones: [`docs/m0.md`](docs/m0.md), [`docs/m1.md`](docs/m1.md), [`docs/m2.md`](docs/m2.md), [`docs/m3.md`](docs/m3.md).
Repo: https://github.com/cybrid-systems/aura-evolve

This is not a traffic dashboard and not an Elo project. The product is the
Aura loop: hot-strategy, worldline search, MutationBoundary, relower.

- **M0** races `strat-agg` and `strat-calm` host-sequential. It does not call
  `hot-strategy` or `fiber:spawn`. Stamp: `WORLD line=host-sequential joins=0/2`.
- **M1** swaps and heals the `ev:choose` slot mid-run, then races the same
  two bodies. `fiber_live` only when both fiber joins return scores.
  Otherwise `host-sequential`. See `docs/m1.md`.
- **M2** gates a proposed `(lambda (age own other) ...)` and KEEPs it only
  when its score is strictly greater than the current main. A tie or a loss
  is DROP plus `hot-strategy:heal!`. HTTP is host-side only.
- **M3** is a two-intersection corridor. Each node has its own NS/EW queues.
  A policy is shared (same body on both nodes) or per-node. The score is the
  sum: throughput − queue − stop. `ETAPE` lines are the append-only evolution
  tape (`out/tape_*.md`). PK burn races proposed bodies on that grid.

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary
`/workspace/aura-grok/build/aura` (host GLIBC is often too old — smoke always
runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`). Soft runs
natively in that container (no nested docker). Never `build_soft4132`.
Needs `AURA_SANDBOX=off`. `python3` is the host interpreter for
`scripts/propose_minimax.py` and `scripts/burn.sh`.

```bash
bash scripts/smoke_soft.sh    # M0 → EVOLVE_M0_OK
bash scripts/smoke_m1.sh      # SWAP / HEAL / KEEP / DROP → EVOLVE_M1_OK
bash scripts/smoke_m2.sh      # fixture propose → EVOLVE_M2_PROPOSE_OK
bash scripts/smoke_m3.sh      # 2-node grid → EVOLVE_M3_OK
bash scripts/smoke.sh         # the stack, plus live MiniMax or LIVE_SKIP
bash scripts/burn.sh          # 3 rounds, horizon 24; fixtures if EVOLVE_PROPOSE=0
EVOLVE_PROPOSE=0 bash scripts/burn_pk.sh   # 4-round grid PK → EVOLVE_PK_OK
bash scripts/replay_tape.sh   # pretty-print the newest out/tape_*.md
```

Scripts may be mode `100644` in git. Always invoke them with `bash`.

Manual Soft run:

```bash
sudo docker run --rm --entrypoint /usr/local/bin/gosu \
  -v /workspace/aura-grok:/workspace/aura-grok \
  -v "$PWD":/workspace/aura-evolve \
  -w /workspace/aura-evolve \
  -e AURA_PATH=/workspace/aura-grok/lib \
  -e AURA_PIPELINE_STRICT=0 \
  -e AURA_SANDBOX=off \
  -e AURA_BIN=/workspace/aura-grok/build/aura \
  ghcr.io/cybrid-systems/dev:v1.0.9 \
  dev /workspace/aura-grok/build/aura /workspace/aura-evolve/soft/evolve/m0_smoke.aura
```

`scripts/run_soft.sh` is the same invocation. The source path is `$1`.
It forwards `EVOLVE_HORIZON`, `EVOLVE_BURN_ROUNDS`, `EVOLVE_ROUND_DIR`,
and `EVOLVE_PROPOSE_FILE` into the container.

On seed `20261005`, 60 ticks, M0 keeps `strat-agg` (mid 1, score `-764`)
and drops `strat-calm` (mid 2, score `-1086`). M1's race prints the same
scores. On the tip binary that race is
`WORLD line=fiber_live backend=2 joins=2/2` (`backend=2` is CLI thread
fallback, not serve-async). M0's own stamp stays `host-sequential`.

M2's chase fixture (`other > own`) scores `-650` and is KEEP. The hold
fixture scores `-2289` and is DROP. Fixture burn (horizon 24) KEEPs round 1
(`-193` vs agg `-241`) and DROPs a tie and a worse body. Detail in
`docs/m2.md`.

M3 seed `20261005`, 60 ticks, two nodes. Shared agg `-1167` KEEP, shared
calm `-1837` DROP. Per-node (node 0 agg, node 1 chase) `-1165` KEEP
(`per-node-higher`). World line on this tip:
`WORLD line=fiber_live backend=2 joins=2/2`. Fixture PK (horizon 24, 4
rounds) baselines agg at `-276`, KEEPs chase `-237`, DROPs flip `-291`,
hold `-731`, and a tie at `-237`. `WORLD line=fiber_live backend=2 joins=8/8`.
Tape: `out/tape_m3.md`, `out/tape_pk.md`. Scoreboard: `out/pk_scoreboard.md`.
Detail in `docs/m3.md`.

## Engine

| Path | Role |
|------|------|
| `soft/evolve/world.aura` | intersection state, arrivals, service, score, `set!` of `*stop-w*` |
| `soft/evolve/strategy.aura` | `strat-agg` / `strat-calm`, M0 host-sequential race, KEEP/DROP |
| `soft/evolve/hot.aura` | `ev:choose` / `ev:shadow`, swap, heal, honest fiber race |
| `soft/evolve/propose.aura` | gate a lambda file, race vs main, KEEP or DROP/heal |
| `soft/evolve/burn.aura` | multi-round propose → gate → play |
| `soft/evolve/grid.aura` | two-node corridor, aggregate score, `ETAPE` |
| `soft/evolve/pk.aura` | sustained PK on the grid |
| `soft/evolve/m0_smoke.aura` | `EVOLVE_M0_OK` |
| `soft/evolve/m1_smoke.aura` | `EVOLVE_M1_OK` |
| `soft/evolve/m2_propose_smoke.aura` | fixture `EVOLVE_M2_PROPOSE_OK` |
| `soft/evolve/m2_live.aura` | one host lambda → `EVOLVE_M2_PROPOSE_LIVE_OK` |
| `soft/evolve/m3_smoke.aura` | `EVOLVE_M3_OK` |
| `soft/evolve/fixtures/` | bad, ugly, worse, better, burn rounds, pk rounds |
| `scripts/propose_minimax.py` | MiniMax HTTP. No key in the tree |
| `scripts/burn.sh` | single-intersection host rounds, then Soft |
| `scripts/burn_pk.sh` | grid PK, `out/pk_scoreboard.md` |
| `scripts/replay_tape.sh` | pretty-print the newest tape |
| `scripts/run_soft.sh` | docker tip binary |

Rules, short form (detail in the milestone docs):

- One phase bit. `0` is NS green, `1` is EW green. Hold or switch once per tick.
- Arrivals are `rng % 3` cars on NS and on EW. The generator is a small LCG from seed `20261005`.
- A red arrival adds to the queue and to the stop penalty. Green serves up to 2 cars.
- Score is `throughput - queue_pen - stop_pen` (integers).
- At tick 24 every worldline does `(set! *stop-w* 3)` and prints `MUTATE`.
- KEEP requires a strictly higher score (M0's tie still keeps agg; M2's tie DROPs).

## Propose

`python3 scripts/propose_minimax.py OUT [ROUND [NOTE [PREV]]]`

Reads `MINIMAX_API_KEY_FILE`, `MINIMAX_BASE_URL`, `MINIMAX_MODEL` from
`~/.config/aura-build/minimax.env`. Default base
`https://api.minimax.cn/v1`, model `MiniMax-M3`. `api.minimaxi.com` is
rewritten to the `.cn` host. Stderr is `PROPOSE_WROTE` or `PROPOSE_FAIL`.
Stdout stays empty. The key is never printed.

## Soft tip

- Binary: `/workspace/aura-grok/build/aura`
- Image: `ghcr.io/cybrid-systems/dev:v1.0.9`
- Env: `AURA_SANDBOX=off AURA_PIPELINE_STRICT=0 AURA_PATH=/workspace/aura-grok/lib`

Soft is not Restricted mode. `fiber_live` is not printed unless the joins
landed. M0 does not register a hot-strategy.

License: Apache-2.0

---

# aura-evolve（中文）

活世界在 Soft：一个路口（城市灯控，或两条产线共用一盏绿灯）。M0 在同一条
种子上赛两条策略，更好的留下（KEEP），更差的丢掉（DROP）。M0 没有 fiber，
印 `host-sequential`。M1 中途 `swap!` / `heal!`，并且只有两条 fiber 都
join 到分数时才印 `fiber_live`（这次是 `backend=2 joins=2/2`，线程回退，
不是假装的调度器）。M2 由宿主脚本向 MiniMax 要一条
`(lambda (age own other) ...)`，Soft 做门禁，分数不比当前主策略高就
DROP 并 heal。密钥不进仓库，也不调用 `api.minimaxi.com`。

```bash
bash scripts/smoke.sh          # M0 + M1 + M2 + M3 + 实况或 SKIP + burn + PK
bash scripts/burn.sh           # 单路口多轮。离线：EVOLVE_PROPOSE=0 bash scripts/burn.sh
EVOLVE_PROPOSE=0 bash scripts/burn_pk.sh   # 两路口 PK，记分牌 out/pk_scoreboard.md
bash scripts/replay_tape.sh    # 打印最新的 out/tape_*.md
```

种子 `20261005`、60 拍：M0 `strat-agg` 分数 -764 KEEP，`strat-calm`
-1086 DROP。M2 追逐体 -650 KEEP，一直不切换 -2289 DROP。
M3 是两条路口的走廊，分数相加。共享 agg -1167 KEEP，calm -1837 DROP；
节点 0 用 agg、节点 1 用 chase 得到 -1165，再 KEEP。这次二进制上
`fiber_live backend=2 joins=2/2`。PK 四轮（地平线 24）主策略停在 -237，
`joins=8/8`。没有 join 就不印 `fiber_live`。
镜像 `ghcr.io/cybrid-systems/dev:v1.0.9`，Soft 二进制
`/workspace/aura-grok/build/aura`。仓库里没有密钥。
