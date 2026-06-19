# 加密波段量化炼蛊机 — 架构方案

> 版本:2026-06-19 · 状态:**待用户确认 → 确认后进 Phase 0 编码**
> 配套:决策台账见项目记忆;证据见 `/Users/hang/AI/trading/crypto-algo-loop-best-practices.md`
> 一句话定位:一台达尔文式策略筛选机 —— 持续淘汰过拟合垃圾,只让验证存活的真货毕业拿真钱。

---

## 1. 设计哲学(锁定)

- **不是「找策略」,是「运营淘汰机制」。** 价值在淘汰机制本身可信,不在某一个策略。
- **核心-卫星杠铃**:核心仓已 BTC 定投/分批(稳);本机器是 ~1% 实验卫星仓(博高赔率)。真实交付物 = 可信策略 + 不自欺的机器,不是这 1% 的钱。
- **fitness 决定一切**:机器朝评分爬山。评分设成「收益」→ 进化出骗子;设成「先存活,再风险调整最优」→ 进化出真货。
- **收益是结果不是入口**:年化 100%+ 是「验证过的 edge × 杠杆」的期望产出,**绝不当准入门槛**。
- **分阶段**:先纸面跑通逻辑,再投真金白银。

---

## 2. 系统总架构

```
   灵感漏斗(TradingView/论文/论坛)──全是「待证伪假设」,不是成品
                    │
                    ▼
 ┌──────────────────── 外循环(慢·人播种假设)────────────────────┐
 │  交易日志失败归因 → 你提新 edge 假设/新策略族 → 喂入内循环        │
 └───────────────────────────────┬──────────────────────────────┘
                                 ▼
 ┌──────────────────── 内循环(快·全自动)──────────────────────┐
 │  ① 生成候选(参数变体) → ② 验证关卡(杀过拟合)                  │
 │       ▲                            │                            │
 │       └──── ④ 变异/重组 ◀── ③ 选择(留幸存者,按 fitness) ──┘   │
 └───────────────────────────────┬──────────────────────────────┘
                                 │ 幸存者
                                 ▼
        ┌──── 准入考(6 条硬门槛全过) ────┐  ── 不过 ──▶ 回炉/淘汰
                                 ▼
                  纸面 forward(dry-run)
                                 ▼
                  真钱卫星仓(全自动上线 + 阶梯放量 + 硬护栏)
                                 ▼
                  交易日志 + MLflow 追踪 → 归因 → 回外循环
```

数据层、回测层贯穿始终;金库式 holdout 全程锁死,只在准入考前看一次。

---

## 3. 自迭代双层循环(机制核心)

### 内循环(全自动,机器几小时跑完)
在**一个策略族内**搜索参数空间:生成数百~数千组参数变体 → 每组过验证关卡 → 杀过拟合 → 在幸存者邻域继续搜(= 优化)。引擎:freqtrade hyperopt / 遗传搜索。

### 外循环(人播种,低频)
内循环只能磨细已知方向;新 edge 需人注入。驱动力 = **交易日志失败归因**(机器告诉你「趋势策略在震荡市连环止损」→ 你提「加震荡 regime 闸门」假设 → 喂回内循环)。灵感漏斗在此进入,当假设不当成品。

### 保命纪律(让自迭代不自欺)
1. **金库式 holdout**:留一段历史锁死,内循环永不触碰,仅准入考前看一次,看过作废。
2. **全局试验预算 N**:跨所有迭代累计计数,DSR 用全局 N 去运气(不是单轮 N)。
3. **前推纪律**:真 OOS 永远来自未来新数据;每次重优化后必须经历纸面 forward 再放量。

---

## 4. Fitness 函数(全局命门)

```
fitness(策略候选):
  # 硬门:任一不过 → fitness = 0(杀)
  if not walk_forward_OOS_pass:        return 0
  if DSR(全局N) not 显著:              return 0
  if PBO > 阈值:                       return 0
  if net_edge(扣费+滑点+funding) <= 0: return 0
  # 过门后打分
  score = Calmar_OOS                   # 年化÷最大回撤,同时奖励收益与控回撤
  score -= 参数不稳定惩罚               # 尖峰扣分,高原加分
  score -= 高换手惩罚                   # 成本侵蚀扣分
  return score
```

**机器朝这个分爬山,而非朝收益爬。** 这是全自动机器不进化成骗子的根本保证。

---

## 5. 验证关卡(可执行定义 + 初始阈值)

> 阈值是起点,Phase 1 用历史数据校准后微调。

| 关卡 | 方法 | 初始阈值 | 挂载 |
|---|---|---|---|
| 无泄漏 | look-ahead 自检 | 必过 | freqtrade lookahead-analysis |
| 样本外 | walk-forward(anchored/rolling) | OOS ≥ IS×70% | 自建 harness 包 freqtrade |
| 去运气 | Deflated Sharpe(全局 N) | DSR > 0 且显著 | 自实现 |
| 防过拟合 | PBO(CSCV) | PBO < 0.5(越低越好) | skfolio/自实现 |
| 信息泄漏 | CPCV + purge + embargo | embargo ~1% | timeseriescv/skfolio |
| 参数稳健 | 高原 vs 尖峰(heatmap) | 邻域±10%绩效相近 | 自建 |
| 路径风险 | Monte Carlo / block bootstrap | 5%分位终值>0,爆仓<1% | 自建 |
| 净 edge | 真实成本模型 | 扣费+滑点+funding 后>0 | freqtrade 费用模型 |

---

## 6. 准入考(Phase1→Phase2,6 条硬门槛全过才上真钱)

| # | 条件 | 门槛 |
|---|---|---|
| ① | 过完整验证关卡 | 第 5 节全部 |
| ② | 样本外一致 | OOS ≥ IS×70% |
| ③ | 纸面站得住 | 1 月 dry-run 不崩 + 对账偏差在阈值内 |
| ④ | 风险调整达标 | OOS Calmar ≥ 地板值(非收益地板) |
| ⑤ | 净 edge 为正 | 扣全成本后>0 |
| ⑥ | 容量够 | BTC 大流动性,天然满足 |

**注意:无「年化≥X」门槛 —— 故意的,防止重开过拟合闸门。**

---

## 7. 自动上线护栏(全自动上线的代偿,不可省)

1. **验证关卡 = 自动上线唯一闸门**,没过的自动化碰都不碰。
2. **单策略仓位硬上限** ≤ 卫星仓 25–30%;**并发策略数上限**(初始 ≤3)。
3. **杠杆硬上限** ≤2–3x(由 -50% 回撤容忍反推)。
4. **阶梯放量**:首单最小手数 → 实盘与回测对账一致 → 才自动加到目标仓位。
5. **卫星仓 -50% 全停熔断** + 单策略三条自动下线(回撤超阈 / drift / 绩效衰减)。
6. **运维安全**:API key 禁提币 + IP 白名单 + `newClientOrderId` 幂等 + 自建 kill switch(交易所不提供断连撤单)+ 心跳告警(Telegram)。

---

## 8. 技术栈定稿(附理由)

| 环节 | 选型 | 理由 |
|---|---|---|
| 语言 | Python 3.11+ | 生态 |
| 执行闭环核心 | **freqtrade** | 加密原生,回测/hyperopt/dry-run/实盘一体,51.6k★活跃,GPL-3.0 |
| 数据/交易所接入 | freqtrade 内置(ccxt)+ Binance 官方 API | 一手 K线/资金费/markPrice |
| 参数大规模扫描 | freqtrade hyperopt(MVP)→ 需要时加 vectorbt | MVP 先用内置,避免过早引入复杂度 |
| CPCV/purge | skfolio 或 timeseriescv | 信息泄漏防护 |
| DSR/PBO | 自实现(~百行) | 无成熟开箱库,核心逻辑简单 |
| 实验追踪 | MLflow | 每次回测=一次 run,记参数/指标/code hash/种子,可复现 |
| 策略注册表 | MLflow Model Registry(或 SQLite) | 幸存者版本化、阶段流转 |
| 告警 | Telegram(freqtrade 内置) | 你已有 telegram-mcp |

> backtrader 已弃维(最后真实提交约 3 年前),不采用。NautilusTrader/LEAN 作为「回测实盘同引擎一致性更强」的未来升级备选,MVP 不引入。

---

## 9. 数据层方案

- **来源**:Binance 官方 API 一手(spot + USDⓈ-M 永续);K线 + fundingRate + markPrice。
- **幸存者偏差**:BTC 单标的起步天然规避;未来扩多币时,补含下架交易对的归档数据。
- **质量**:point-in-time(信号只用已收盘 K 线);用 markPrice 而非 lastPrice 做触发,过滤单所插针。
- **成本模型**:taker/maker 费 + 滑点 + 永续 8h 资金费,全部进回测。
- **本地缓存**:freqtrade `download-data`,按时间框存 parquet。

---

## 10. 交易日志规约(每笔必落,供归因)

信号时间戳与触发条件 · 预期价 vs 实际成交价(→实际滑点)· 订单类型与状态机轨迹 · 费用 · 仓位规模 · 当时市场状态快照(波动率/价差/趋势 regime 标签)· 策略版本 hash · 决策依据指标值。**关键:逐笔留「预期 vs 实际」,才能区分策略失效还是执行失效。**

---

## 11. 目录结构

```
/Users/hang/AI/trading/
├── architecture-design.md            # 本文档
├── crypto-algo-loop-best-practices.md # 调研报告
├── pyproject.toml / requirements.txt
├── config/
│   ├── config.dryrun.json            # 纸面
│   └── config.live.json              # 真钱(密钥走环境变量,不入库)
├── data/                             # K线/funding 缓存(gitignore)
├── strategies/                       # 策略族(freqtrade IStrategy)
│   └── trend_following_v1.py
├── research/
│   ├── walk_forward.py               # 滚动前推 harness
│   ├── cpcv.py                       # CPCV + purge + embargo
│   ├── deflated_sharpe.py            # DSR
│   ├── pbo.py                        # PBO
│   ├── monte_carlo.py                # 路径风险
│   └── fitness.py                    # 第4节 fitness 函数
├── validation/
│   └── admission_gate.py             # 第6节准入考(6条硬门槛)
├── registry/                         # 幸存者注册表(MLflow / SQLite)
├── journal/                          # 交易日志落盘
├── live/
│   └── guardrails.py                 # 第7节护栏(仓位/杠杆/阶梯/熔断)
├── ops/
│   └── kill_switch.py                # 心跳 + 断连撤单
└── mlruns/                           # MLflow(gitignore)
```

---

## 12. 三阶段路线

| 阶段 | 内容 | 退出/毕业线 |
|---|---|---|
| **Phase 0** 搭机器(~1–2 周) | 数据→回测→walk-forward→纸面 跑通,单策略族 | 跑出第一个可测闭环 |
| **Phase 1** 纸面自迭代(时间盒 **1 个月**) | 全自动炼蛊,统计力靠历史 walk-forward/CPCV,1 月纸面做 sanity check | 有≥1 策略过准入考 → Phase2;**一个都没有 → 复盘是方法问题还是 edge 够不到** |
| **Phase 2** 真钱(1% 卫星仓) | 全自动上线 + 阶梯放量 + 硬护栏 | **卫星仓 -50% 钱盒 → 全停复盘** |

---

## 13. Phase 0 MVP 落地清单(确认后从这里开干)

1. 环境:Python venv + 安装 freqtrade + MLflow + skfolio。
2. 数据:freqtrade 拉 BTC/USDT 现货 + 永续历史 K线 + funding(几年)。
3. 策略族 ①:**趋势跟踪**(EMA 交叉 + ATR 止损 + 波动率仓位)作第一个「物种」(最简、文献 edge 最硬的方向)。
4. `research/walk_forward.py`:滚动前推 harness,只上报拼接 OOS。
5. `research/deflated_sharpe.py` + `pbo.py`:最小可用版,挂到 walk-forward 输出。
6. `research/fitness.py`:实现第 4 节 fitness。
7. MLflow:每次回测记 params/metrics/code hash/随机种子。
8. `journal/`:交易日志 schema 落盘。
9. freqtrade `dry-run`:把策略族 ① 挂上纸面跑起来。
10. 跑通后产出第一份「炼蛊报告」:候选数、存活数、幸存者 fitness 排名。

> 资金费率收割(市场中性)作为策略族 ②,Phase 1 再加 —— 它需要永续 + 对冲,比趋势复杂,不放进 MVP。

---

## 14. 已锁决策 / 未决项 / 风险

**已锁**:
- ✅ **edge 起步顺序**:Phase 0 先做趋势跟踪(directional);资金费率收割(structural)Phase 1 加入。
- ✅ **Phase 2 用永续合约**:以支持 2–3x 杠杆 / 做空 / 吃资金费(代价:强平 + funding 风险,§7 护栏必须到位)。

**未决 / 风险**:
- **DSR/PBO 阈值**:初始值需 Phase 1 用真实数据校准,可能偏松或偏紧。
- **1 月时间盒的统计风险**:已用历史 walk-forward 补统计力,但纸面 1 月仍是薄样本,毕业的幸存者要警惕「侥幸过关」。
- **交易所账号**:Phase 2 需要 Binance(或替代)API key,届时按运维安全清单配置。
```
