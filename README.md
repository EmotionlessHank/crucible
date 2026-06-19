# crucible

> A crucible: burn off overfit dross, let only validation-survivors graduate to real money.
> 一个坩埚:炼脱过拟合杂质,只让验证存活的真货毕业拿真钱。

A Darwinian strategy-culling machine for crypto swing trading. It does not "find one good strategy" —
it **continuously generates candidates, kills overfit junk through strict validation gates, and lets only
survivors graduate to real money.** The value lives in a trustworthy culling mechanism, not in any single strategy.

一台达尔文式的策略筛选机。它不「找一个好策略」,而是**持续生成候选 → 用严苛验证关卡淘汰过拟合垃圾 → 只让幸存者毕业拿真钱**。价值在淘汰机制本身可信,不在某一个策略。

---

## Navigation / 导航

- 📐 [Architecture / 架构方案](./docs/architecture-design.md)
- 🔬 [Best-practices research / 调研报告](./docs/best-practices-research.md)
- 🗂 [Docs index / 文档导航](./docs/INDEX.md)
- 🤖 [Project rules (CLAUDE.md)](./CLAUDE.md)

---

## English

- **Market**: large-liquidity **BTC**, swing (hours–days holding), perpetual futures in the live phase; IBKR later.
- **Capital structure**: core-satellite barbell. Core is already DCA'd; this machine is a ~1% experimental
  satellite sleeve for asymmetric upside. Real deliverable = trustworthy strategies + a machine that does not deceive itself.
- **Objective**: absolute return (positive annual + controlled drawdown). 100%+ annual is an *outcome* of
  (validated edge × leverage), **never an admission criterion**.

### Core design

- **Two-layer self-iteration**: inner loop (automated parameter search) + outer loop (human-seeded edge
  hypotheses, driven by trade-journal attribution).
- **Anti-overfit fitness**: the machine climbs "survive first, then risk-adjusted-best (Calmar)", not raw
  return — the root guarantee that a fully automated machine does not evolve into a liar.
- **Survival-based admission**: gates on walk-forward / DSR / PBO / parameter-plateau / net-edge / paper-holds.
  **No return threshold.**
- **Phases**: P0 build → P1 paper self-iteration (1-month time-box) → P2 real money (1% sleeve, auto-deploy + hard guardrails).

### Tech stack

Python · freqtrade (execution loop) · vectorbt (parameter sweeps) · skfolio/timeseriescv (CPCV) ·
custom DSR/PBO · MLflow (experiment tracking) · Binance official API (data).

### Status

🚧 Phase 0 pending — architecture locked, engineering scaffold in progress.

---

## 中文

- **主战场**:大流动性 **BTC**,波段(持仓数小时~数天),实盘阶段用永续合约;后续可迁 IBKR。
- **资金结构**:核心-卫星杠铃。核心仓已 BTC 定投/分批;本机器是 ~1% 实验卫星仓,博高赔率。真实交付物 = 可信策略 + 不自欺的机器。
- **目标函数**:绝对收益(年化为正 + 控回撤);年化 100%+ 是「验证过的 edge × 杠杆」的期望产出,**不是准入门槛**。

### 核心设计

- **双层自迭代**:内循环(全自动参数搜索)+ 外循环(人播种新 edge 假设,由交易日志失败归因驱动)。
- **fitness 抗过拟合**:机器朝「先存活,再风险调整最优(Calmar)」爬山,而非朝收益爬 —— 全自动机器不进化成骗子的根本保证。
- **存活式准入**:6 条硬门槛(walk-forward / DSR / PBO / 参数高原 / 净 edge / 纸面站得住),**无收益门槛**。
- **分阶段**:P0 搭机器 → P1 纸面自迭代(1 月时间盒)→ P2 真钱(1% 卫星仓,全自动上线 + 硬护栏)。

---

## Dev setup

```bash
bash scripts/setup-hooks.sh   # enable the pre-commit secret guard (once per clone)
```

## ⚠️ Risk disclaimer / 风险声明

Quant trading is high-risk. Research shows crypto swing edges are thin, behavioral, cost-sensitive, and decay;
~97% of retail day traders lose money. This is a personal experiment, **not investment advice**.
**Secrets and live config are never committed** (see `.gitignore` and `.githooks/pre-commit`).

量化交易高风险。本仓库是个人实验项目,非投资建议。**密钥与实盘配置绝不入库**。
