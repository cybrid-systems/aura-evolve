# aura-evolve — design (Aura-native)

The product is a live Soft FlatAST world: the intersection (queues, phase,
green age, seed) and the strategy slots are Soft definitions in one Aura
process. A thin C program will be a viewport. It is not the simulator.
M0 does not ship that viewport.

This is the same loop aura-tetris and aura-go already play. Soft owns the
state. Strategy bodies are what a later `hot-strategy:swap!` /
`hot-strategy:heal!` will replace. Worldlines race. A bad line is stolen
back (rollback / DROP). A good line is stamped (KEEP) into the main world.
The artifact is a replayable evolution tape, not a static dashboard.

M0 stops before `hot-strategy` and before fibers. The race it needs is
already Soft, and the stamp is honest: `host-sequential`.

## One sentence

Painting a signal head is hygiene. The product is: Soft owns the crossing,
two policies race the same seed, the worse worldline is dropped, the better
body is kept in the main slot, and the tape says why.

## North star

City light and factory light are one model. NS / EW are either two road
approaches or two conveyors that share a single green window. The law does
not fork into a second language for the factory reading.

1. **FlatAST owns the world.** Phase, queues, throughput, stop penalty,
   queue penalty, RNG, and the main strategy slot are workspace data.
2. **Bad strategy: rollback / DROP.** Its score is recorded. Its final
   queues are not the main world. The slot binding is not updated to it.
3. **Good strategy: stamp / KEEP.** The winning body is the main slot, then
   that body is run again from the same seed so the live world is the
   kept tape.
4. **Replayable tape.** `TAPE` lines, `MUTATE`, `RACE`, `KEEP`, `DROP` are
   the audit. A later C blit may draw them. It does not choose the winner.
5. **Aura loop (the product, not all of it is in M0).**
   - hot-strategy: swap / heal a policy body without retconning the seed law
   - fibers: several worldlines for real, stamped `fiber_live` only when
     every `fiber:join` returns a landing
   - MutationBoundary: a weight change that is logged and bounded
   - relower: the kept body is the one the next tick lowers back into
   M0's stand-in for MutationBoundary is a plain `(set! *stop-w* 3)` at
   tick 24, printed as `MUTATE`. It does not call `mutate:rebind`.
   aura-go already saw `eval-current` wipe a live board; M0 does not call it.

## What M0 actually does

```
m0_smoke.aura
    │  load world + strategy
    ▼
host-sequential fork (reset to the same seed, twice)
    │  strat-agg (mid 1)     short green, chase the longer queue
    │  strat-calm (mid 2)    long green, switch when idle or capped
    ▼
compare integer scores
    │  KEEP higher  (tie keeps agg)
    │  DROP lower   (reason lower-score-rollback)
    ▼
replay winner into the main world
    │  TAPE every 10 ticks
    ▼
EVOLVE_M0_OK
```

`WORLD line=host-sequential joins=0/2`. There is no `fiber:spawn` in M0.
Do not print `fiber_live`.

## Soft vs C

| Soft owns | C may do (later) |
|-----------|------------------|
| phase, queues, RNG, score | blit of the tape |
| which body is the main slot | nothing about KEEP/DROP |
| the `set!` of `*stop-w*` | nothing about the weight |

C must not keep a second intersection.

## Soft ≠ Restricted

| | This product | Not this product |
|--|----------------|------------------|
| World | FlatAST workspace defines | A native plugin / `.so` region |
| Swap (later) | `std/hot-strategy` | `std/hot-update` (`aot:reload`) |
| Heal (later) | `hot-strategy:heal!` | `std/heal` mid-tick surgery |
| Sandbox | **off** (same as aura-go / aura-film smoke) | Restricted mode as the play loop |
| Fibers | honest `fiber_live` or `host-sequential` | a label with no join |

M0 does not register a hot-strategy and does not spawn a fiber.

## Score

`throughput - queue_pen - stop_pen`.

- Each tick, NS and EW each receive `0..2` cars (`LCG % 3`).
- Cars that arrive on red add that many to `*stops*` and add
  `*stop-w* * count` to `*stop-pen*` immediately, so the tick-24 weight
  change does not retcon earlier stops.
- The green side departs up to 2 cars (throughput).
- After service, both queues add into `*queue-pen*`.

The absolute number is often negative. That is a penalty, not a bug.
KEEP uses the greater score.

## Non-goals

- Not a city-scale network, not a PLC, not SUMO.
- Not a dashboard that only plots one fixed schedule.
- Not a fake `fiber_live` and not a pretend `hot-strategy:swap!`.
- Not a C-authoritative light "for latency".
- Not a second strategy language. Bodies are the same Soft the smoke runs.
- No keys in the tree.

## Files

| Path | Role |
|------|------|
| `soft/evolve/world.aura` | state, tick, score, mutate log |
| `soft/evolve/strategy.aura` | two bodies, race, KEEP/DROP |
| `soft/evolve/m0_smoke.aura` | evidence, `EVOLVE_M0_OK` |
| `docs/m0.md` | the scripted numbers |
| `scripts/smoke_soft.sh` | docker tip binary |

## 中文

产品是可回放的进化带，不是看板。Soft 拥有路口和策略槽。差的世界线
rollback / DROP，好的 stamp / KEEP 进主世界。环路仍是 aura-tetris /
aura-go 那一套（热策略、fiber、MutationBoundary、relower）。M0 还没有
真的 swap，也没有 fiber。第 24 拍只是 `(set! *stop-w* 3)`，并打印
`MUTATE`。没有 join 就不印 `fiber_live`。
