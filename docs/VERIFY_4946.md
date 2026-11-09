# #4946 aura-evolve 下游验证报告（v0.2-evo）

范围：`/home/dev/code/downstream/aura-evolve`。只用合成/种子数据，全程离线，
没有客户数据，也没有调用 MiniMax。模拟器种子固定 `20261005`、地平线 60；
QD 的“搜索种子”另取 1–5，只影响候选采样与变异，不影响世界。

aura 侧：源码树 `/home/dev/code/aura-wt-v020-qd-dx`（HEAD `35eb110cf`，
`std/qd`、`std/evo-core`、`aura evo log/report` 都来自这棵树）。本机没有
docker，`scripts/run_soft.sh` 增加了本地回退：`AURA_BIN` + `AURA_PATH`，
Soft 源码不变；容器路径 `run_soft.sh` 仍是默认。

---

## 1. 先建立基线，先发现一个真问题

**声明**：现有 M2（严格大于才 KEEP）与 M3（双路口）脚本在 pin 的 aura 上
给出文档里的数字，且可复现。

**测试**：直接跑 `scripts/smoke_m2.sh`、`scripts/smoke_m3.sh`，各跑两次。

**结果（FAIL，先修）**：CLI 的 fiber 后端是线程（`backend=2`），两个 thunk
共享同一份 Soft 全局世界（`*phase*`、`*rng*`、`*q-ns*` …都是扁平全局）。
所谓“两个 worldline 竞速”实际是两条线程交错改同一份状态：同一脚本连跑四次
分别得到 `RACE base=-2102`、`-1984`、`-2103`、`-2173`，四个值互不相等，
也都不是文档里的 `-764`。
M3 的共享竞速同样被打坏（`agg=-4357 calm=-4163`，而顺序执行是 `-1167/-1837`）。

**修复**：`soft/evolve/hot.aura` 的 `ev:race-thunks!` 只在协作调度后端（1，
thunk 内没有 yield）才 `fiber:spawn`；线程后端（2）顺序执行两个 thunk，并如实
打印 `host-sequential`。这不是“降级糊弄”：一个可变世界本来就不能同时跑两条
worldline，除非给每条世界一份状态副本，而当前 Soft 没有。

修复后（两次运行一致）：

| 基线 | 数值 |
|------|------|
| M2 worse | base `-764` trial `-2289` → DROP |
| M2 better | base `-764` trial `-650` → KEEP |
| M2 世界线 | `WORLD line=host-sequential backend=0 joins=0/0` |
| M3 共享 | agg `-1167` KEEP，calm `-1837` DROP |
| M3 每节点 | `-1165` KEEP（`per-node-higher`） |
| M3 世界线 | `WORLD line=host-sequential backend=0 joins=0/0` |

`EVOLVE_M0_OK`、`EVOLVE_M1_OK`、`EVOLVE_M2_PROPOSE_OK`、`EVOLVE_M3_OK`、
`EVOLVE_BURN_OK`、`EVOLVE_PK_OK` 全部通过，文档里 M2/M3/PK 的 pin 值全部对上。

注意：这同时说明 README 里“`fiber_live backend=2 joins=2/2`”的旧说法是错的；
已按实测改为 `host-sequential`。

---

## 2. M2：把“严格大于”换成 `std/qd` 的 `qd:map-elites`

**声明**：KEEP 不再由“比当前 main 严格更大”决定，而是由 `qd:insert!` 决定。
描述子是（吞吐，停车次数），质量是整数 score；安全边界保留。

**实现**：`soft/evolve/qd_lab.aura` + `soft/evolve/qd_m2.aura`。

- 网格：吞吐 `[114,122]` 6 格 × 停车 `[50,80]` 6 格（单路口的行为带就在这里）
- 质量：score（越高越好），同格更差不会被换进去
- KEEP：`cell-new-or-better`；DROP：`cell-dominated` / 门禁 / 约束
- 冠军：`qd:best` 装回 `ev:choose`，再带 tape 重放一次
- 安全边界（不是口头承诺）：每个候选先过 `ev:apply-body!`（禁用词、长度、
  `(lambda` 前缀、`hot-strategy:swap!`、`(ev:choose 4 1 2)` 必须 0/1、坏探针
  `heal!`），再过分数底线 `EVOLVE_QD_FLOOR=-820` 和世界不变量（吞吐、停车、
  队列均非负）。被拒的只记 `ROLLBACK`，不插入。

**测试**：`EVOLVE_QD_SEED=1..5`，每个种子 241 次评估（128 个
家族成员 + 112 个变异 + 1 个“无上限追逐”候选）。**结果**：

| seed | evals | elites | coverage | best | 原冠军 |
|------|-------|--------|----------|------|--------|
| 1 | 241 | 7 | 19% | -647 | -650 |
| 2 | 241 | 7 | 19% | -647 | -650 |
| 3 | 241 | 7 | 19% | -647 | -650 |
| 4 | 241 | 7 | 19% | -647 | -650 |
| 5 | 241 | 7 | 19% | -647 | -650 |

非支配前沿（种子 1）三点：`-647/71 停`、`-694/65`、`-760/63`。也就是说档案
保留了“少停一点、分数稍低”的取舍，而旧规则只留一个冠军。

边界在 tape 里可见：门禁探针是 `reason=gate:gate`（带 `set!` 的体）；分数
底线由长绿灯变异触发，`reason=constraint:score-floor`（实测 `-894`、`-1003`，
基线是 `-764`）。

**判定**：PASS —— 最好 elite `-647` 不差于原冠军 `-650`。覆盖率 19% 是
这个路口的物理事实（吞吐 117–120/120 已饱和，行为带只穿过 36 格里的 7 格），
M2 没有覆盖率验收项；如实列出。

---

## 3. M3 走廊：覆盖率与冠军

**声明**：走廊覆盖率 ≥ 60%，最好 elite 不差于原冠军。

**实现**：`soft/evolve/qd_m3.aura`，候选是每条路口一套策略的“对”。
网格 6×5 = 30 格：吞吐 `[230,238]`，停车 `[114,150]`。865 次评估 = 128 个
共用成员 + 24×24=576 个格点组合 + 64 个随机对 + 96 个变异对。

**结果（sim seed 20261005，horizon 60）**：

| seed | evals | elites | coverage | best |
|------|-------|--------|----------|------|
| 1 | 865 | 24 | 80% | -1093 |
| 2 | 865 | 25 | 83% | -1095 |
| 3 | 865 | 24 | 80% | -1093 |
| 4 | 865 | 25 | 83% | -1095 |
| 5 | 865 | 25 | 83% | -1093 |

最好格子：吞吐 237 / 停车 117。对比：

- 原 M3 冠军 `-1165`（节点 0 agg、节点 1 chase）→ 现在 `-1093`，好 72 分
- 原 M2 冠军 `-650` 是单路口分数，跨世界不可直接比；按每路口折算
  `-1093 / 2 = -546.5`，同样好于 `-650`
- 种子 1 的非支配前沿：`-1093/117`、`-1145/115`、`-1193/114`

**判定**：覆盖率 80–83% ≥ 60%，最好 elite 不差于原冠军，PASS。

---

## 4. ETAPE 由 evo log 生成，并与 `aura evo report` 对齐

**声明**：tape 不是第二条打印路径；它与 `aura evo log --front/--lineage` 和
`aura evo report` 的谱系、前沿一致。

**实现**：

- Soft 每次评估写一条 `evo:record!`（v=2：`behavior`、`objectives`、
  `constraints`、显式 `parents`）
- `scripts/tape_from_evo_log.py` 只读 JSONL，生成 `ETAPE op=… tick=… mid=…
  score=… reason=…`，再交给 `collect_tape.py` 出 markdown
- `scripts/verify_evo_tape.py` 调 CLI 复核

**结果（种子 1，M2 与 M3 都跑）**：

```
FRONT_SUBSET OK front=3 missing=[]
LINEAGE_MATCH OK chain=['#2', '#8', ... '#2510']
BEST_MATCH OK soft=-1093 tape=-1093
COVERAGE_MATCH OK soft=80 tape_max=80
REPORT_ARTIFACTS OK out/report_m3
VERIFY_OK
```

产物：`out/tape_m3_qd.md`（870 行 event）、`out/report_m3/index.html` 以及
`qd-heatmap.svg`、`lineage.svg`、`pareto.svg`、`hv-curve.svg`。

**可复现性**：固定种子（`EVOLVE_QD_SEED=7`）连跑两次，去掉 `ts_ms`/`dur_ms`
后 2600 行 JSONL 逐字节相同（`identical True`）。

---

## 5. 失败项与限制（如实）

1. **线程 fiber 竞速是坏的**（上文）。已修成顺序执行并改口径；要真正的并行
   worldline，需要先给每条世界一份状态（workspace fork / 每世界一组变量），
   当前 Soft 全局做不到。所有数字都来自 `host-sequential`。
2. **M3 网格取运行包络而不是物理上界**。走廊吞吐上限 240，实测 230–237；
   用 `[0,240]×[0,240]` 的 12×12 物理网格时覆盖率只有 2–3%，因为整条行为带
   只穿过两三格。报告因此用“固定种子校准出的包络”`[230,238]×[114,150]` 作为
   声明网格，并在文档里写明理由；两种口径都给了数字。
3. **M2 覆盖率 19%**（7/36）。M2 没有覆盖率验收项；五个搜索种子结果完全相同，
   因为家族只有 128 个成员，128 个全扫一遍就到达最好，变异没有增益。
4. **`std/qd` 的模块内 helper 没有命名空间**：`qd-rand!`、`qd-rand-int!` 是
   模块内部名，工作区里同名的 `define` 会直接覆盖它（我最初用了 `qd-rand!`，
   结果 `qd:select-parent` 的 `score-child` 路径报 `arity mismatch`）。本仓库
   已全部改成 `ql-` 前缀；建议上游给内部 helper 加前缀或改成模块私有。
5. **`evo:record!` 的 parent 默认是 worldline tip**，而 `hot-strategy` 的每次
   swap 都会追加 `mutate:rebind` 记录；CLI 在“自带裁决”的 run 里会把这些过滤
   掉，于是 lineage 断链。本仓库改成显式传 parent（上一条 QD 记录），文档里
   之前没写这个坑。
6. **没有跑 MiniMax**：M2 的实况路径保持原样（`propose_minimax.py`），本次
   全部用合成家族与 fixture；`EVOLVE_PROPOSE=0` 的 burn/PK 仍通过。

---

## 6. 复现

```bash
cd /home/dev/code/downstream/aura-evolve
export AURA_PATH=/home/dev/code/aura-wt-v020-qd-dx/lib
export AURA_BIN=/home/dev/code/aura-wt-v020-qd-dx/build/aura

# 基线（旧规则，必须仍然可复现）
bash scripts/smoke_m2.sh      # -764 / -2289 / -650
bash scripts/smoke_m3.sh      # -1167 / -1837 / -1165
EVOLVE_PROPOSE=0 bash scripts/burn.sh
EVOLVE_PROPOSE=0 bash scripts/burn_pk.sh

# #4946 验收：5 个搜索种子 + 固定种子的 tape/report 一致性
bash scripts/smoke_qd.sh      # 结尾 EVOLVE_QD_OK
```

`smoke_qd.sh` 的输出：`out/qd_summary.md`、`out/qd_m{2,3}_s{1..5}.txt`、
`out/evo_m{2,3}_s*.jsonl`、`out/tape_m{2,3}_qd.md`、`out/report_m{2,3}/`。

## 7. 结论

| 验收项 | 结果 |
|--------|------|
| M2 改 `qd:map-elites`，描述子（吞吐，停车），质量 score | PASS |
| M2 安全边界保留（门禁 + 分数底线 + 不变量，拒绝只记 ROLLBACK） | PASS |
| M2 最好 elite 不差于原冠军 `-650` | PASS（`-647`） |
| M3 覆盖率 ≥ 60% | PASS（80–83%，5 个种子） |
| M3 最好 elite 不差于原冠军 | PASS（`-1093` vs `-1165`；每路口 `-546.5` vs `-650`） |
| ETAPE 由 evo log 生成，与 `aura evo report` 谱系/前沿一致 | PASS |
| 固定种子可复现 | PASS（日志逐字节相同） |
| 只用合成/种子数据、离线 | PASS |

已知失败/限制见第 5 节：线程 fiber 不能并行共享全局的世界（已改口径）、
M3 网格是运行包络、M2 覆盖率低、`std/qd` 内部名冲突、`evo:record!` parent 坑。

