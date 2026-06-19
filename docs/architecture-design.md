# Crypto Swing Algo Culling Machine — Architecture Design

> Version: 2026-06-19 · Status: **Pending user confirmation → Phase 0 coding begins after confirmation**
> Companion: decision log in project memory; evidence in `/Users/hang/AI/trading/crypto-algo-loop-best-practices.md`
> One-line positioning: A Darwinian strategy-screening machine — continuously culling overfitting junk, letting only validated survivors graduate to real capital.

---

## 1. Design Philosophy (Locked)

- **Not "find a strategy" — operate an elimination mechanism.** The value lies in the credibility of the elimination mechanism itself, not in any single strategy.
- **Core-satellite barbell**: the core sleeve already holds BTC DCA/laddered buys (stable); this machine is the ~1% experimental satellite sleeve (high-odds bets). The real deliverable = credible strategies + a machine that doesn't deceive itself — not the 1% capital.
- **Fitness determines everything**: the machine hill-climbs toward its score. Set the score to "returns" → evolves cheaters; set it to "survive first, then risk-adjusted optimum" → evolves genuine edge.
- **Returns are an output, not an entry criterion**: 100%+ annualized is the expected output of "validated edge × leverage" — **never used as an admission gate**.
- **Phased**: logic proven on paper first, real capital second.

---

## 2. Overall System Architecture

```
   Inspiration funnel (TradingView / papers / forums) — all "hypotheses to falsify", not finished products
                    │
                    ▼
 ┌──────────────────── Outer loop (slow · human seeds hypotheses) ────────────────────┐
 │  Trade-log failure attribution → you propose new edge hypothesis / strategy family → feed into inner loop  │
 └───────────────────────────────┬──────────────────────────────┘
                                 ▼
 ┌──────────────────── Inner loop (fast · fully automated) ──────────────────────┐
 │  ① Generate candidates (parameter variants) → ② Validation gates (kill overfitting)  │
 │       ▲                            │                                            │
 │       └──── ④ Mutate/recombine ◀── ③ Select (keep survivors, rank by fitness) ──┘  │
 └───────────────────────────────┬──────────────────────────────┘
                                 │ Survivors
                                 ▼
        ┌──── Admission gate (all 6 hard criteria passed) ────┐  ── fail ──▶ rework / eliminate
                                 ▼
                  Paper forward (dry-run)
                                 ▼
                  Live satellite sleeve (fully automated launch + laddered sizing + hard guardrails)
                                 ▼
                  Trade log + MLflow tracking → attribution → back to outer loop
```

Data layer and backtest layer run throughout; vault-style holdout is locked at all times — opened only once before the admission gate.

---

## 3. Self-Iterating Two-Layer Loop (Mechanism Core)

### Inner Loop (fully automated, machine completes in hours)
Searches the parameter space **within a single strategy family**: generates hundreds to thousands of parameter variants → each passes the validation gates → kills overfitting → continues searching in the neighborhood of survivors (= optimization). Engine: freqtrade hyperopt / genetic search.

### Outer Loop (human-seeded, low frequency)
The inner loop can only refine known directions; new edge requires human injection. Driver = **trade-log failure attribution** (the machine tells you "trend strategy triggered chain stop-losses in a ranging market" → you propose "add ranging-regime gate" hypothesis → feed back into inner loop). The inspiration funnel enters here — treated as hypotheses, not finished products.

### Survival Discipline (keeping self-iteration honest)
1. **Vault-style holdout**: one segment of history locked permanently; the inner loop never touches it; opened only once before the admission gate — once seen, invalidated.
2. **Global trial budget N**: cumulative count across all iterations; DSR uses global N to adjust for luck (not per-round N).
3. **Forward discipline**: true OOS always comes from future new data; after every re-optimization a paper forward period must be completed before scaling up.

---

## 4. Fitness Function (The Global Linchpin)

```
fitness(strategy_candidate):
  # Hard gates: any failure → fitness = 0 (kill)
  if not walk_forward_OOS_pass:        return 0
  if DSR(global_N) not significant:    return 0
  if PBO > threshold:                  return 0
  if net_edge(after fees+slippage+funding) <= 0: return 0
  # Score after passing gates
  score = Calmar_OOS                   # annualized / max drawdown — rewards both return and drawdown control
  score -= parameter_instability_penalty  # spiky peaks penalized, plateaus rewarded
  score -= high_turnover_penalty          # cost erosion penalized
  return score
```

**The machine hill-climbs toward this score, not toward returns.** This is the fundamental guarantee that a fully automated machine does not evolve into a cheater.

---

## 5. Validation Gates (Executable Definitions + Initial Thresholds)

> Thresholds are starting points; fine-tune after calibration with historical data in Phase 1.

| Gate | Method | Initial Threshold | Mounted On |
|---|---|---|---|
| No lookahead | look-ahead self-check | must pass | freqtrade lookahead-analysis |
| Out-of-sample | walk-forward (anchored/rolling) | OOS ≥ IS×70% | custom harness wrapping freqtrade |
| Luck-adjusted | Deflated Sharpe (global N) | DSR > 0 and significant | custom implementation |
| Anti-overfitting | PBO (CSCV) | PBO < 0.5 (lower is better) | skfolio / custom implementation |
| Information leakage | CPCV + purge + embargo | embargo ~1% | timeseriescv / skfolio |
| Parameter robustness | plateau vs. spike (heatmap) | ±10% neighborhood performs similarly | custom build |
| Path risk | Monte Carlo / block bootstrap | 5th-percentile terminal value > 0, ruin < 1% | custom build |
| Net edge | realistic cost model | > 0 after fees + slippage + funding | freqtrade cost model |

---

## 6. Admission Gate (Phase 1 → Phase 2: all 6 hard criteria required before live capital)

| # | Condition | Criterion |
|---|---|---|
| ① | Passes all validation gates | Section 5 in full |
| ② | Out-of-sample consistency | OOS ≥ IS×70% |
| ③ | Paper trading holds up | 1-month dry-run without collapse + reconciliation deviation within threshold |
| ④ | Risk-adjusted hurdle met | OOS Calmar ≥ floor value (not a return floor) |
| ⑤ | Positive net edge | > 0 after all costs |
| ⑥ | Sufficient capacity | BTC high liquidity — naturally satisfied |

**Note: no "annualized ≥ X" criterion — intentional; prevents reopening the overfitting gate.**

---

## 7. Auto-Launch Guardrails (Compensation for Full Automation — Non-Negotiable)

1. **Validation gates = the sole auto-launch gate**: nothing that hasn't passed is touched by automation.
2. **Hard position cap per strategy** ≤ satellite sleeve 25–30%; **concurrent strategy count cap** (initial ≤3).
3. **Hard leverage cap** ≤2–3x (back-calculated from -50% drawdown tolerance).
4. **Laddered sizing**: first trade at minimum lot → live vs. backtest reconciliation consistent → then auto-scale to target position.
5. **Satellite sleeve -50% full-stop circuit breaker** + per-strategy three auto-delisting triggers (drawdown exceeds threshold / drift / performance decay).
6. **Ops security**: API key withdrawal disabled + IP whitelist + `newClientOrderId` idempotency + custom kill switch (exchange provides no disconnect-cancel) + heartbeat alert (Telegram).

---

## 8. Final Tech Stack (With Rationale)

| Component | Choice | Rationale |
|---|---|---|
| Language | Python 3.11+ | Ecosystem |
| Execution loop core | **freqtrade** | Crypto-native, backtest/hyperopt/dry-run/live in one system, 51.6k★ active, GPL-3.0 |
| Data / exchange access | freqtrade built-in (ccxt) + Binance official API | First-party OHLCV / funding rate / markPrice |
| Large-scale parameter scan | freqtrade hyperopt (MVP) → add vectorbt when needed | Use built-in for MVP; avoid premature complexity |
| CPCV / purge | skfolio or timeseriescv | Information-leakage protection |
| DSR / PBO | Custom implementation (~100 lines) | No mature off-the-shelf library; core logic is simple |
| Experiment tracking | MLflow | Each backtest = one run; records params / metrics / code hash / seed; reproducible |
| Strategy registry | MLflow Model Registry (or SQLite) | Survivor versioning, stage transitions |
| Alerts | Telegram (freqtrade built-in) | telegram-mcp already available |

> backtrader is unmaintained (last real commit ~3 years ago) — not adopted. NautilusTrader / LEAN are future upgrade candidates ("stronger backtest-live engine consistency") — not introduced in MVP.

---

## 9. Data Layer Design

- **Source**: Binance official API first-party (spot + USDⓈ-M perpetuals); OHLCV + fundingRate + markPrice.
- **Survivorship bias**: single-asset BTC start naturally avoids it; when expanding to multiple assets, supplement with archived data including delisted pairs.
- **Quality**: point-in-time (signals use only fully closed candles); use markPrice rather than lastPrice for triggers — filters single-exchange wick spikes.
- **Cost model**: taker/maker fees + slippage + perpetual 8h funding rate — all included in backtest.
- **Local cache**: freqtrade `download-data`, stored as parquet by timeframe.

---

## 10. Trade Log Schema (Per-Trade Required — For Attribution)

Signal timestamp and trigger conditions · expected price vs. actual fill price (→ realized slippage) · order type and state-machine trace · fees · position size · market-state snapshot at the time (volatility / spread / trend regime label) · strategy version hash · indicator values that drove the decision. **Key: per-trade "expected vs. actual" is what distinguishes strategy failure from execution failure.**

---

## 11. Directory Structure

```
/Users/hang/AI/trading/
├── architecture-design.md             # this document
├── crypto-algo-loop-best-practices.md # research report
├── pyproject.toml / requirements.txt
├── config/
│   ├── config.dryrun.json             # paper trading
│   └── config.live.json               # live capital (secrets via env vars, not committed)
├── data/                              # OHLCV / funding cache (gitignore)
├── strategies/                        # strategy families (freqtrade IStrategy)
│   └── trend_following_v1.py
├── research/
│   ├── walk_forward.py                # rolling walk-forward harness
│   ├── cpcv.py                        # CPCV + purge + embargo
│   ├── deflated_sharpe.py             # DSR
│   ├── pbo.py                         # PBO
│   ├── monte_carlo.py                 # path risk
│   └── fitness.py                     # Section 4 fitness function
├── validation/
│   └── admission_gate.py              # Section 6 admission gate (6 hard criteria)
├── registry/                          # survivor registry (MLflow / SQLite)
├── journal/                           # trade log persistence
├── live/
│   └── guardrails.py                  # Section 7 guardrails (position / leverage / ladder / circuit breaker)
├── ops/
│   └── kill_switch.py                 # heartbeat + disconnect-cancel
└── mlruns/                            # MLflow (gitignore)
```

---

## 12. Three-Phase Roadmap

| Phase | Content | Exit / Graduation Criterion |
|---|---|---|
| **Phase 0** Build the machine (~1–2 weeks) | Data → backtest → walk-forward → paper — end-to-end runnable, single strategy family | First complete closed loop runs through |
| **Phase 1** Paper self-iteration (time-box **1 month**) | Fully automated crucible; statistical power from historical walk-forward/CPCV; 1-month paper as sanity check | ≥1 strategy passes admission gate → Phase 2; **zero pass → post-mortem: methodology problem or edge genuinely unreachable** |
| **Phase 2** Live capital (1% satellite sleeve) | Fully automated launch + laddered sizing + hard guardrails | **Satellite sleeve money-box -50% → full stop + post-mortem** |

---

## 13. Phase 0 MVP Delivery Checklist (Start Here After Confirmation)

1. Environment: Python venv + install freqtrade + MLflow + skfolio.
2. Data: freqtrade pulls BTC/USDT spot + perpetual historical OHLCV + funding (several years).
3. Strategy family ①: **trend following** (EMA crossover + ATR stop-loss + volatility-based sizing) as the first "species" (simplest; hardest literature-backed edge direction).
4. `research/walk_forward.py`: rolling walk-forward harness, reports concatenated OOS only.
5. `research/deflated_sharpe.py` + `pbo.py`: minimum viable version, attached to walk-forward output.
6. `research/fitness.py`: implement Section 4 fitness function.
7. MLflow: log params / metrics / code hash / random seed for every backtest run.
8. `journal/`: trade log schema persisted to disk.
9. freqtrade `dry-run`: attach strategy family ① and run on paper.
10. After end-to-end run, produce first "crucible report": candidate count, survivor count, survivor fitness ranking.

> Funding-rate harvesting (market-neutral) is strategy family ②, added in Phase 1 — it requires perpetuals + hedging, more complex than trend following; excluded from MVP.

---

## 14. Locked Decisions / Open Items / Risks

**Locked**:
- ✅ **Edge ramp-up order**: Phase 0 starts with trend following (directional); funding-rate harvesting (structural) joins in Phase 1.
- ✅ **Phase 2 uses perpetual contracts**: to support 2–3x leverage / short selling / funding-rate capture (trade-off: liquidation + funding risk; §7 guardrails must be in place).

**Open / Risks**:
- **DSR/PBO thresholds**: initial values need calibration with real data in Phase 1; may be too loose or too tight.
- **Statistical risk of the 1-month time-box**: historical walk-forward supplements statistical power, but 1 month of paper trading is still a thin sample — survivors that graduate should be flagged for potential "lucky pass."
- **Exchange account**: Phase 2 requires a Binance (or alternative) API key; configure per ops-security checklist at that time.
