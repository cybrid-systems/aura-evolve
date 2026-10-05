# aura-evolve

Aura Evolve is a live Soft world. One intersection — city approaches or two
factory lines sharing a green — plus the two strategy slots that race it,
are a Soft FlatAST program. A thin C viewport, later, only blits frames.
M0 has no C binary: the race already runs headless.

Design: [`docs/DESIGN.md`](docs/DESIGN.md). Milestone: [`docs/m0.md`](docs/m0.md).
Repo: https://github.com/cybrid-systems/aura-evolve

This is not a traffic dashboard and not an Elo project. The product, same
as aura-tetris and aura-go, is the Aura loop: hot-strategy, worldline
search, MutationBoundary, relower. M0 is the first playable skeleton of
that loop: two bodies, one seed, KEEP the better, DROP the worse, and an
auditable tape. It does not call `hot-strategy` and it does not stamp
`fiber_live`.

## Soft smoke

Image `ghcr.io/cybrid-systems/dev:v1.0.9`, Soft tip binary
`/workspace/aura-grok/build/aura` (host GLIBC is often too old — smoke always
runs Soft inside Docker with `--entrypoint /usr/local/bin/gosu`). Soft runs
natively in that container (no nested docker). Never `build_soft4132`.
Needs `AURA_SANDBOX=off`. `python3` is the interpreter name on PATH when a
later host tool needs Python; M0 smoke does not call it.

```bash
bash scripts/smoke_soft.sh    # dual race → KEEP / DROP / EVOLVE_M0_OK
bash scripts/smoke.sh         # alias of smoke_soft.sh
```

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

`scripts/run_soft.sh` is the same invocation with the source path as `$1`.

On seed `20261005`, 60 ticks, the kept tape is `strat-agg` (mid 1,
score `-764`) and the dropped tape is `strat-calm` (mid 2, score `-1086`).
Absolute scores are penalty-heavy; the comparison is the product. The
stamp is `WORLD line=host-sequential joins=0/2`.

## Engine

| Path | Role |
|------|------|
| `soft/evolve/world.aura` | intersection state, arrivals, service, score, `set!` of `*stop-w*` |
| `soft/evolve/strategy.aura` | `strat-agg` / `strat-calm`, host-sequential race, KEEP/DROP |
| `soft/evolve/m0_smoke.aura` | load, race, evidence → `EVOLVE_M0_OK` |

Rules for M0, short form (detail in `docs/m0.md`):

- One phase bit. `0` is NS green, `1` is EW green. Hold or switch once per tick.
- Arrivals are `rng % 3` cars on NS and on EW. The generator is a small LCG from seed `20261005`.
- A red arrival adds to the queue and to the stop penalty. Green serves up to 2 cars.
- Score is `throughput - queue_pen - stop_pen` (integers).
- At tick 24 every worldline does `(set! *stop-w* 3)` and prints `MUTATE`.
- Both strategies replay from the same seed. The worse final state is not the main world (rollback / DROP). The winner is run again into the main slot (stamp / KEEP).

## Soft tip

- Binary: `/workspace/aura-grok/build/aura`
- Image: `ghcr.io/cybrid-systems/dev:v1.0.9`
- Env: `AURA_SANDBOX=off AURA_PIPELINE_STRICT=0 AURA_PATH=/workspace/aura-grok/lib`

Soft is not Restricted mode. M0 does not register a hot-strategy and does
not spawn a fiber. Saying otherwise would be a fake stamp.

License: Apache-2.0

---

# aura-evolve（中文）

活世界在 Soft：一个路口（城市灯控，或两条产线共用一盏绿灯），两个策略槽
在同一条种子上赛世界线。更好的留下（KEEP / stamp），更差的丢掉
（DROP / rollback）。C 以后只做画面。M0 没有 C 程序。

这不是静态看板，也不是等级分。产品环路与 aura-tetris、aura-go 相同：
热策略、世界线、MutationBoundary、relower。M0 只交出可玩的骨架。
没有真的 fiber join，印的是 `host-sequential`，不冒充 `fiber_live`。
也还没有调用 `hot-strategy`。

```bash
bash scripts/smoke_soft.sh   # KEEP / DROP，结尾 EVOLVE_M0_OK
```

种子 `20261005`、60 拍：`strat-agg`（mid 1，分数 -764）留下，
`strat-calm`（mid 2，分数 -1086）回滚。第 24 拍 `(set! *stop-w* 3)`。
镜像 `ghcr.io/cybrid-systems/dev:v1.0.9`，Soft 二进制
`/workspace/aura-grok/build/aura`。仓库里没有密钥。
