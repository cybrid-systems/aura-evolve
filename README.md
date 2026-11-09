# aura-evolve

Aura Evolve is a live Soft world. One intersection — city approaches or two
factory lines sharing a green — plus the strategy slots that race it, are a
Soft FlatAST program. A thin C viewport, later, only blits frames. There is
no C binary in this tree yet.

Design: [`docs/DESIGN.md`](docs/DESIGN.md).
Milestones: [`docs/m0.md`](docs/m0.md), [`docs/m1.md`](docs/m1.md), [`docs/m2.md`](docs/m2.md), [`docs/m3.md`](docs/m3.md).
#4946 verification (Chinese): [`docs/VERIFY_4946.md`](docs/VERIFY_4946.md).
Repo: https://github.com/cybrid-systems/aura-evolve

This is not a traffic dashboard and not an Elo project. The product is the
Aura loop: hot-strategy, worldline search, MutationBoundary, relower.

- **M0** races `strat-agg` and `strat-calm` host-sequential. It does not call
  `hot-strategy` or `fiber:spawn`. Stamp: `WORLD line=host-sequential joins=0/2`.
- **M1** swaps and heals the `ev:choose` slot mid-run, then races the same
  two bodies. `fiber_live` only when both fiber joins return scores.
  Otherwise `host-sequential`. See `docs/m1.md`.
- **M2** gates a proposed `(lambda (age own other) ...)`, then decides with
  `std/qd`: a MAP-Elites archive whose descriptors are (throughput, stops)
  and whose quality is the integer score. A candidate is KEEP when it fills
  or improves a cell; a dominated cell and a gate/constraint rejection are
  DROP. The champion is the best elite, stamped into `ev:choose`. The old
  "strictly greater than the main" loop is kept as the A/B baseline
  (`scripts/smoke_m2.sh`, `burn.sh`, `burn_pk.sh`). HTTP is host-side only.
- **M3** is a two-intersection corridor. Each node has its own NS/EW queues.
  A policy is shared (same body on both nodes) or per-node. The score is the
  sum: throughput − queue − stop. The corridor runs the same MAP-Elites
  archive over policy pairs and must cover ≥ 60% of its declared 6×5
  descriptor grid. `ETAPE` lines are generated from the evo log, not from a
  second print path. PK burn races proposed bodies on that grid.

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
bash scripts/smoke_qd.sh      # M2/M3 MAP-Elites acceptance → EVOLVE_QD_OK
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
`EVOLVE_PROPOSE_FILE`, `EVOLVE_QD_*`, `AURA_EVO_LOG` and `AURA_EVO_RUN`
into the container. Without docker (or with `EVOLVE_RUNNER=local`) it runs
a native `AURA_BIN` with `AURA_PATH` instead, on the same sources; that is
how the #4946 numbers were measured.

On seed `20261005`, 60 ticks, M0 keeps `strat-agg` (mid 1, score `-764`)
and drops `strat-calm` (mid 2, score `-1086`). M1's race prints the same
scores. That race is `WORLD line=host-sequential backend=0 joins=0/0`: the
one world is one mutable Soft workspace, so two live worldlines alias, and
the CLI thread backend cannot give each one its own copy. Racing them is a
corruption, not a speedup (#4946). Only a cooperative scheduler backend with
no yield inside the thunks may stamp `fiber_live`.

M2's chase fixture (`other > own`) scores `-650` and is KEEP. The hold
fixture scores `-2289` and is DROP. Fixture burn (horizon 24) KEEPs round 1
(`-193` vs agg `-241`) and DROPs a tie and a worse body. Detail in
`docs/m2.md`.

M3 seed `20261005`, 60 ticks, two nodes. Shared agg `-1167` KEEP, shared
calm `-1837` DROP. Per-node (node 0 agg, node 1 chase) `-1165` KEEP
(`per-node-higher`). World line on this tip:
`WORLD line=host-sequential backend=0 joins=0/0`. Fixture PK (horizon 24, 4
rounds) baselines agg at `-276`, KEEPs chase `-237`, DROPs flip `-291`,
hold `-731`, and a tie at `-237`.
Tape: `out/tape_m3.md`, `out/tape_pk.md`. Scoreboard: `out/pk_scoreboard.md`.
The QD corridor (`scripts/smoke_qd.sh`) reaches 80–83% coverage of its 6×5
grid with a best elite of `-1093`, better than the `-1165` champion. Detail
in `docs/m3.md` and `docs/VERIFY_4946.md`.

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
| `soft/evolve/qd_lab.aura` | MAP-Elites archive, policy family, gate + floor + log |
| `soft/evolve/qd_m2.aura` | M2 under `std/qd` (`EVOLVE_QD_M2_OK`) |
| `soft/evolve/qd_m3.aura` | corridor under `std/qd` (`EVOLVE_QD_M3_OK`) |
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
| `scripts/tape_from_evo_log.py` | evo log → ETAPE lines (one source) |
| `scripts/verify_evo_tape.py` | tape vs `aura evo log/report` |
| `scripts/qd_summary.py` | 5-seed table + acceptance checks |
| `scripts/smoke_qd.sh` | M2/M3 QD acceptance (`EVOLVE_QD_OK`) |
| `scripts/run_soft.sh` | docker tip binary |

Rules, short form (detail in the milestone docs):

- One phase bit. `0` is NS green, `1` is EW green. Hold or switch once per tick.
- Arrivals are `rng % 3` cars on NS and on EW. The generator is a small LCG from seed `20261005`.
- A red arrival adds to the queue and to the stop penalty. Green serves up to 2 cars.
- Score is `throughput - queue_pen - stop_pen` (integers).
- At tick 24 every worldline does `(set! *stop-w* 3)` and prints `MUTATE`.
- M0's tie still keeps agg. The live M2/M3 rule is a MAP-Elites insert
  (`qd:insert!`): better-in-cell is KEEP, dominated is DROP. The legacy
  single-champion scripts keep the strictly-higher rule for comparison.

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
印 `host-sequential`。M1 中途 `swap!` / `heal!`；CLI 只有线程后端（2），
两条 worldline 共享同一份 Soft 全局状态，真并发会互相污染（#4946），所以
顺序执行并印 `host-sequential`，只有协作调度后端且两个 join 都落数才印
`fiber_live`。M2 由宿主脚本向 MiniMax 要一条
`(lambda (age own other) ...)`，Soft 做门禁；实况判决改成 `std/qd` 的
`qd:map-elites`（描述子吞吐/停车，质量 score），纪律仍是“安全边界不过就
DROP”。密钥不进仓库，也不调用 `api.minimaxi.com`。

```bash
bash scripts/smoke.sh          # M0 + M1 + M2 + M3 + 实况或 SKIP + burn + PK
bash scripts/burn.sh           # 单路口多轮。离线：EVOLVE_PROPOSE=0 bash scripts/burn.sh
EVOLVE_PROPOSE=0 bash scripts/burn_pk.sh   # 两路口 PK，记分牌 out/pk_scoreboard.md
bash scripts/replay_tape.sh    # 打印最新的 out/tape_*.md
```

种子 `20261005`、60 拍：M0 `strat-agg` 分数 -764 KEEP，`strat-calm`
-1086 DROP。M2 追逐体 -650 KEEP，一直不切换 -2289 DROP。
M3 是两条路口的走廊，分数相加。共享 agg -1167 KEEP，calm -1837 DROP；
节点 0 用 agg、节点 1 用 chase 得到 -1165，再 KEEP。这次二进制上是
`host-sequential backend=0 joins=0/0`（线程后端不真并发）。PK 四轮
（地平线 24）主策略停在 -237。QD 走廊五种子覆盖率 80–83%，最好 elite
-1093，好于 -1165；详见 `docs/VERIFY_4946.md`。
镜像 `ghcr.io/cybrid-systems/dev:v1.0.9`，Soft 二进制
`/workspace/aura-grok/build/aura`。仓库里没有密钥。
