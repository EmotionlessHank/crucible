# Crypto (BTC) Swing Quant Closed-Loop — Industry Best Practices Report

> Version: 2026-06-19 · Primary arena: BTC/Crypto (swing, holding hours to days) · Portable to IBKR later
> Method: 4-track parallel research + source audit. Core claims are anchored to academic primaries (SSRN/NBER/Journal of Finance/Elsevier) and official exchange documentation; signal-sellers/course-sellers/profit-screenshot vendors/tool-vendor advertorials are downweighted and flagged ⚠️.
> Purpose: This is the methodological foundation for a sustainable self-iterating closed loop of "find → backtest → optimize → live." Read Sections 0, 6, and 7 first.

---

## 0. Core Conclusions (TL;DR)

1. **"Find a great strategy" inverts causality.** After fees, markets are a negative-sum game — every dollar you earn must be continuously lost by someone else. The real question is not "which strategy is great," but "which BTC swing alpha hasn't yet been arbitraged away by market makers/quant funds/arb bots, and can retail reliably capture it?" If you can't answer that, any pretty backtest is just overfitting to historical noise.
2. **Literature-supported crypto swing edge is real but thin, behavioral in nature, highly cost-sensitive, and subject to decay.** There is no "money printer." The realistic path is a **stacked layer** of trend + regime gate + strict risk control + funding rate harvesting, aimed at improving risk-adjusted returns and drawdowns.
3. **TradingView belongs only in the "inspiration funnel," never in "strategy sources."** Over 95% of scripts repaint; highly-liked public strategies are either already overfit or already arbitraged. Treat every script as a "hypothesis to be falsified" — it must be retested with your own data and rigorous validation.
4. **The biggest danger of a "self-iterating closed loop" is itself.** Automated periodic re-optimization continuously refits out-of-sample data into the in-sample window, mass-producing strategies that are "perfect yesterday, zero tomorrow." **What should be automated is "rapidly falsifying bad strategies"; what should never be automated is "the go-live decision."** Most retail traders have this backwards.
5. **A high backtest Sharpe is nearly worthless** unless you can prove it isn't the result of luck cherry-picked from hundreds or thousands of trials (corrected with Deflated Sharpe / PBO).
6. **Three hard live-trading constraints**: API keys must disable withdrawals + IP whitelist + idempotent order placement; build your own kill switch (exchanges don't provide disconnect-triggered cancel-all); perpetual strategies must model 8-hour funding costs in both backtest and real-time P&L.

---

## 1. Crypto Swing Strategies: Documented Edge and Data/Cost Reality

> Core: Literature edge is real but thin; most shrinks dramatically or disappears entirely once realistic costs are factored in.

### 1.1 Edge Evidence by Strategy Prototype

| Prototype | Literature Evidence Strength | Edge Source | Decay / Pitfalls |
|---|---|---|---|
| **Time-series momentum/trend (TSM)** | Relatively strong | Behavioral "overreaction" | Significance disappears for many portfolios once costs are included |
| **Cross-sectional momentum (multi-coin)** | Weak–Medium | Same as above | Weaker than TSM; depends on dead coins and illiquid small-caps |
| **Mean reversion / pairs trading** | Medium (declining) | Cointegration convergence | Increased competition + arbitrage risk; profitability has declined significantly |
| **Funding rate / cash-and-carry** | Medium (structural) | Structural long payment in perpetuals | Only ~40% of top opportunities are positive after costs |
| **Volatility timing / risk-control overlay** | Medium (risk-control value > alpha selection) | Peak/tail reduction | Improves Sharpe/drawdown, not raw returns |

- **Time-series momentum** is the most consistently evidenced direction in crypto. Liu/Tsyvinski (NBER w24877, later published in *Journal of Finance* 2022) found that a 1 standard-deviation rise in BTC daily returns predicts +0.33% the next day, significant at daily/weekly frequencies. However, Han/Kang/Ryu re-examined this under "realistic assumptions (including costs + intraday volatility)": **many statistically significant momentum portfolios show insignificant net returns, and a large number of portfolios are liquidated**; the premium is primarily driven by overreaction rather than risk compensation → the edge is behavioral and decays as the market matures.
- **Funding rate arbitrage** is a **structurally unique crypto edge** (perpetual longs chronically pay shorts), but academic primaries show that only ~17% of observed arbitrage spreads are ≥20bps, and **only ~40% of top opportunities are positive after costs and spread reversals**. In other words, "market-neutral funding rate harvesting" works, but net alpha is far smaller than the advertised double-digit APRs.
- **Volatility tools are a "risk-management overlay," not independent alpha** — their real contribution is reducing drawdown and lifting Sharpe (e.g., raising BTC buy-and-hold Sharpe from 0.72 to 1.21).

### 1.2 Regime Dependence
The fact that trend/momentum is **strong in bull markets and weak in bear/ranging markets** is a robust finding. BTC historical bear market drawdowns are approximately -75% to -84%, lasting 9–14 months. Practical regime gates: **long-cycle moving average direction + realized volatility percentile + funding rate sign** (bull/bear/ranging × high/low vol) — not trying to predict exact turning points.

### 1.3 Crypto Data Reality (the most overlooked source of losses)
- **Survivorship bias is the most lethal**: CMC has listed ~24,000 coins since 2013, of which more than 14,000 are dead (failure rate >58%). Testing only "coins alive today" systematically overstates returns (one measured example: +2800% vs +680%, roughly 4× inflation). ⚠️ The specific percentages come from a data vendor blog; the direction is credible but exact values require verification against your own data.
- **Delisted coin history is purged**: Exchanges routinely delete OHLCV data for delisted trading pairs, contaminating cross-sectional momentum especially.
- **Clean data practices**: ① OHLCV / funding rates / mark prices via official exchange APIs (Binance/OKX/Bybit) as primary; ② supplement with third-party archives that include delisted pairs to close survivorship bias gaps; ③ use Mark Price (index-weighted) rather than Last Price for backtest triggers, filtering single-exchange flash spikes; ④ separate spot vs. derivatives — fees/basis only exist in derivatives.

### 1.4 Reality of the Cost Model
- Binance (2026): Spot 0.1% taker/maker; USD-margined perpetuals ~0.05% taker / 0.02% maker (use the official fee schedule as the primary source).
- **Total real cost = fees + spread + slippage + perpetual funding**. Swing round-trip using taker: perpetuals ~0.10%+ per round trip, spot ~0.20%+.
- Crypto momentum raw edge is often in the range of "a few basis points intraday" → **the higher the turnover, the more completely edge is consumed by costs**. Swing is more cost-tolerant than intraday, but still requires **maker/limit orders only on each side**, controlled turnover — otherwise net alpha approaches zero.

### 1.5 In One Sentence: Retail-Accessible Edge
**A stacked layer, not a money printer**: time-series trend + regime gate + strict risk control (stop-loss / volatility targeting) + structural funding rate harvesting, preserving the thin cost-residual edge under low turnover. **Don't expect**: highly accurate high-frequency signals, double-digit risk-free funding APR, altcoin momentum backtests ignoring dead coins, or any public/paid off-the-shelf strategy.

---

## 2. Strategy Validation and Anti-Overfitting (The Project's True Moat)

> Core proposition: A high backtest Sharpe is worthless unless you can prove it isn't luck cherry-picked from hundreds or thousands of trials.

1. **In-sample/Out-of-sample + Walk-Forward Analysis (rolling forward)**: Optimize on IS, evaluate on the immediately following OOS, step the window forward. For BTC swing, recommended IS:OOS ≈ 4:1 to 6:1; report only the stitched OOS curve — IS numbers are never trusted. Pitfall: repeatedly looking at and adjusting OOS burns it into IS.
2. **CPCV + Purging + Embargo (López de Prado)**: Overlapping labels in financial data violate i.i.d.; standard k-fold inevitably leaks information. Purge removes samples where label periods overlap with the test set; Embargo further removes a short adjacent segment (~1%); CPCV generates multiple backtest paths and outputs a Sharpe **distribution**. Tools: `mlfinlab` (partially closed-source), `timeseriescv`, `skfolio`.
3. **Multiple testing / data-snooping bias (the most lethal)**: Running 1,000 parameter combinations and picking the highest Sharpe is almost certainly positive purely by luck. Corrections required:
   - **Deflated Sharpe Ratio (DSR)**: Subtract "the highest SR expected to appear from N random trials" from the observed SR, adjusted for skewness/kurtosis/sample length. Estimate N as the number of effective independent trials via clustering.
   - **White's Reality Check / Hansen SPA**: Test whether the best rule has genuine excess returns relative to the benchmark (SPA has higher power).
   - **PBO (Probability of Backtest Overfitting)**: Estimate "the probability that the IS-optimal strategy underperforms the median in OOS."
4. **Parameter stability: plateau vs. spike**: Choose a **broad plateau** where neighbors ±10% also perform well, not an isolated **spike** (noise — will collapse in live trading). Optimal parameters selected across WFA windows should cluster, not jump erratically.
5. **Monte Carlo / Bootstrap**: Resample trade sequences with replacement to generate distributions of return curves / maximum drawdown. Criteria: 5th-percentile terminal value still positive; 95th-percentile MDD within acceptable range; ruin probability <1%. **MC 95th-percentile MDD commonly reaches 3× the backtest figure — this is the number to size positions by.** (Use block bootstrap for trend strategies to preserve autocorrelation.)
6. **Three fatal backtest biases**: look-ahead (deciding on unclosed candles), survivorship (testing only surviving coins), repainting / exchange data issues (repainting, retroactive revisions, flash spikes).
7. **Closed-loop self-iteration's own overfitting (the project's greatest risk)** — four counterdisciplines:
   - **Vault holdout**: Lock away one data segment; view it exactly **once** immediately before going live — once seen, it is invalid.
   - **Global trial budget**: Count N cumulatively across all iterations; DSR uses this global N.
   - **Forward discipline**: True OOS always comes from newly arrived future data; after every re-optimization, mandatory paper/small-position live before scaling.
   - **PBO gating**: Reject any iteration round where PBO is too high.

---

## 3. Self-Iterating Closed-Loop Engineering Architecture

### 3.1 End-to-End Pipeline Layers and Hard Gates

Unidirectional pipeline with hard gates between layers — no advancing without passing (prevents bias compounding across layers):

| Layer | Output | Gate to Next Layer |
|---|---|---|
| Research / Hypothesis | Signal logic + economic intuition | Hypothesis is falsifiable; pre-specified logic exists (not pure data mining) |
| Backtest (IS) | Return curve, metrics | Lookahead/leak self-check passes; sufficient trade count |
| Hyperopt | Parameter set | ≤6 parameters; OOS drawdown consistent |
| Walk-forward / OOS | Rolling window performance | OOS performance ≥ ~70% of IS; profit factor / MDD stable across windows |
| Paper / Dry-run | Live-market paper fills | 30–60 days real-time paper; slippage/fees consistent with model |
| Live (small position) | Real fills | P&L reconciliation error vs. parallel OOS within threshold |
| Feedback → Research | Trade log attribution | Attribution conclusions drive next hypothesis round, not direct parameter tweaks |

### 3.2 Actual Maintenance Status of Major Open-Source Frameworks (verified via gh api)

| Framework | Archived | Last Push | Stars | License | Closed-Loop Role | Rating |
|---|---|---|---|---|---|---|
| **freqtrade** (+FreqAI+hyperopt) | No | 2026-06-18 | 51.6k | GPL-3.0 | Crypto-native **full closed-loop**: backtest/hyperopt/dry-run/live/adaptive modeling in one | High |
| **NautilusTrader** | No | 2026-06-18 | 24.0k | LGPL-3.0 | Rust core, **backtest↔live on the same engine** (strongest consistency) | High |
| **QuantConnect LEAN** | No | 2026-06-18 | 20.0k | Apache-2.0 | Multi-asset, **built-in Reconciliation** | High |
| **vectorbt** (open-source) | No | 2026-06-10 | 8.0k | NOASSERTION | Vectorized **large-scale parameter sweep / research**; not for live execution | Medium |
| **backtrader** | No | Last real commit ~2023-04 (~3 years ago) | 22.0k | GPL-3.0 | **Effectively unmaintained** — study only, do not use in production | Low |

Key point: backtrader is not marked archived but has had no substantive updates in ~3 years = abandoned (many blogs still recommend it — exactly why you need to check primary sources). Choose the primary closed-loop framework from **freqtrade / NautilusTrader / LEAN**.

### 3.3 Reproducibility Metadata (required on every backtest/optimization run)
Code version (git commit hash) + parameter set + data date range and data source snapshot + **random seed** + dependency lockfile + fee/slippage model + metric results. Any missing element invalidates the conclusion. Tools: **MLflow Tracking + Model Registry** (treat each backtest as one run); lightweight alternative: custom SQLite/JSON registry.

### 3.4 Trade Journal Specification
Every trade must record: signal timestamp and trigger conditions, **expected price vs. actual fill price (→ realized slippage)**, order type and state-machine trace, fees, position size, **market state snapshot at time of trade (volatility/spread/depth/trend label)**, corresponding strategy version hash, and indicator values that drove the decision. Attribution key: keeping "expected vs. actual" per trade is what distinguishes strategy failure from execution/slippage failure.

### 3.5 Backtest–Live Reconciliation
LEAN paradigm: **run a parallel OOS backtest alongside live trading**; ideally the two equity curves overlap — any divergence indicates the execution environment mismatches the model. Calibration: backfill the simulator with empirical slippage/fees from 30–60 days of paper/small-position live. **Takedown triggers**: reconciliation error or drawdown exceeds threshold, OOS drops below 70% of IS, profit factor collapses → kill switch / halt and return to research layer, not live parameter tweaking.

### 3.6 Self-Iteration: Correct Practice vs. Dangerous Anti-patterns
- **Anti-pattern**: Automated periodic re-hyperopt = repeatedly fitting to the latest history = burning out-of-sample.
- **Correct**: Re-optimization output is treated as a "candidate pending validation" — it must pass through genuine forward testing gates before going live.
- **Three manual checkpoints**: ① Does the hypothesis have economic intuition? ② Do optimal parameters jump erratically after re-optimization (drift = overfitting signal)? ③ Go-live / takedown decisions. Automate only mechanically deterministic tasks (lookahead self-check, reconciliation, log attribution, alerting).

---

## 4. Live Execution, Risk Control, and Operations

### 4.1 Venue Selection (BTC): Spot vs. Perpetuals
Look at four things: **API maturity, matching rule transparency, fee structure, rate-limit rules** (not trading volume rankings). Perpetuals have an additional **funding rate** cost item (Binance default settles every 8 hours, can compress to 1 hour at limits); multiple settlement windows during a swing hold significantly erode P&L — must be modeled. Spot has no leverage/liquidation/funding, suitable for medium-to-long swings that don't require short exposure. Verifiable items: rate limits are multidimensional (REQUEST_WEIGHT / order count / WS connections); response headers return consumed weight and must be read for adaptive back-off; sustained 429s without back-off will result in IP bans (escalating from 2 minutes to 3 days); before placing orders, pull LOT_SIZE/MIN_NOTIONAL per symbol and align.

### 4.2 Paper Trading / Forward Test
freqtrade officially states: **only forward testing (dry-run) can truly validate a strategy**. After dry-run, compare against backtest over the same period — signals should land on the same candle (fill prices will naturally differ). **How long to run**: no official hard number; experience suggests at least one complete volatility cycle (BTC ≥4–8 weeks) with ≥30 independent trades accumulated; swing strategies typically require 1–3 months. "Ran two weeks and was profitable" is insufficient grounds for going live.

### 4.3 Position Sizing and Risk Management (Actionable Numbers)
- **Per-trade risk**: CFA convention ≤2% of total capital per trade; swing recommendation 0.5%–2% per trade.
- **Fractional Kelly**: Use ½ or ¼ Kelly (half-Kelly halves volatility while only reducing expected growth by 25%). Kelly says 4% → actually deploy 1–2%.
- **Volatility targeting**: Scale position by (target annualized volatility ÷ recent realized volatility) (Moreira & Muir show this can improve Sharpe ~25%). ⚠️ **Must use only lagged (realized) volatility — future data is strictly forbidden** (the original construction has a look-ahead controversy). Recommended target annualized volatility for crypto: 15%–30%.
- **Circuit breaker / kill switch**: Suspend new entries if intraday drawdown ≥3%–5%; full halt and manual review if cumulative drawdown ≥15%–20%. Circuit breaker thresholds should be materially below backtest maximum drawdown.

### 4.4 Operations and Security Checklist
- ☐ API key permissions minimized, **withdrawals disabled** (funds cannot be stolen even if keys leak)
- ☐ IP whitelist bound to fixed egress
- ☐ **Idempotent duplicate-order prevention**: all orders carry a unique client-generated `newClientOrderId`; retries reuse the same ID
- ☐ **Self-built kill switch**: ⚠️ Binance Spot API **does not provide** disconnect-triggered auto-cancel — must implement locally: heartbeat loss → cancel-all + halt new entries
- ☐ Heartbeat / alert monitoring (process, WS, balance, position vs. local state consistency → Telegram / PagerDuty)
- ☐ After disconnect/reconnect, reconcile against exchange as source of truth before resuming

### 4.5 Live vs. Backtest P&L Gap
Performance degradation from backtest to live of **20%–50% is common** (worst for short-cycle strategies). Sources: slippage, latency, commissions, funding rates, liquidity. Rule of thumb: **expected return must be ≥2–3× trading costs**. Monitoring: record "theoretical fill price vs. actual fill price" per trade; rolling statistics on realized slippage / actual fee rate / cumulative funding; periodically feed live fills back into backtest for comparison.

### 4.6 Common Ways Retail Algo Traders Blow Up
① Excessive leverage ② Overfit strategy goes live (backtest Sharpe has extremely weak predictive power for OOS — correlation commonly <0.05) ③ No circuit breaker / kill switch ④ Fire and forget (deploy and never monitor — the most common) ⑤ Ignoring funding rates ⑥ Risk control weaker than the strategy (a mediocre strategy with strict risk control outperforms a "smart" strategy with thin risk control over the long run).

---

## 5. Synthesis: Recommended Closed-Loop Architecture Blueprint (Pending Your Confirmation)

```
                    ┌─────────────────────────────────────────────┐
                    │  Inspiration Funnel (TradingView/papers/     │
                    │  forums) → all are hypotheses               │
                    └───────────────────┬─────────────────────────┘
                                        ▼
   [Research Layer] Hypothesis + economic intuition ── gate: falsifiable? ──▶ else discard
                                        ▼
   [Data Layer] Official exchange API (OHLCV/funding/markPrice) + third-party with dead coins
                point-in-time, including cost/slippage/funding model
                                        ▼
   [Backtest Layer] vectorbt (fast sweep) ── lookahead self-check ──▶ fail → fix
                                        ▼
   [Validation Layer] walk-forward + CPCV + DSR/PBO ── gate: DSR significant & param plateau & OOS≥IS×70%
                      ↑ Global trial budget counter N (cumulative across iterations)
                                        ▼
   [Paper Layer] freqtrade dry-run ≥4–8 weeks / ≥30 trades ── gate: signals consistent & slippage matched
                                        ▼
   [Live Layer] Start small + parallel OOS reconciliation + kill switch + tiered circuit breakers
                ↑ Risk control: 0.5–2%/trade, ¼–½ Kelly, vol target, withdrawals disabled+IP whitelist+idempotent
                                        ▼
   [Log Layer] Per-trade journal (expected vs. actual) + MLflow experiment tracking (reproducible)
                                        ▼
   [Attribution Layer] Live deviates from backtest? drift? ── yes ──▶ halt, carry attribution back to research layer
                        ⚠️ Manual checkpoints: ① economic intuition ② param drift ③ go-live/takedown  ←── not fully automated
```

**Preliminary tech stack** (pending confirmation):
- Research / sweep: `vectorbt` (open-source version is sufficient)
- Validation statistics: `skfolio` / `timeseriescv` (CPCV) + custom DSR/PBO implementation
- Full closed-loop execution: `freqtrade` (crypto-native, dry-run + live + hyperopt integrated, mature community)
- Experiment tracking: `MLflow`
- Data: Binance/OKX official API + delisted-coin archive supplement
- (For strongest backtest–live engine consistency: `NautilusTrader` — steeper learning curve)

---

## 6. Hard Questions Still Requiring Your Answers (grill — determines architecture direction)

> These are required inputs before architecture is finalized. Especially 1/2/3/7.

1. **What is your edge hypothesis?** (Behavioral bias? Structural funding rate? Information? Or not yet considered?)
2. **Who prevents overfitting in the loop?** Can you accept "the system finds a strategy with 300% annualized backtest returns, but discipline prevents going live"?
3. **How much capital? What drawdown can you tolerate without manually intervening? (Give specific numbers)**
4. **Is the benchmark set to "outperform BTC DCA (equal risk)"? Tear it down if it can't beat that?**
5. **How many hours per week can you commit to maintenance? Are you fantasizing about fully automated passive income?**
6. **What metrics select a "good strategy"? Do you accept strict criteria like Deflated Sharpe / forward consistency / parameter plateau?** (Even if it kills your prettiest strategy?)
7. **Exit conditions (pre-mortem): under what conditions do you admit a strategy is dead? Under what conditions do you admit the entire project direction is wrong and cut losses?**

---

## 7. Source List (credibility rated per source)

### High (Academic Primaries / Official Exchange Documentation)
- Bailey/Borwein/López de Prado/Zhu, *Pseudo-Mathematics and Financial Charlatanism* (Notices of AMS): https://scholarworks.wmich.edu/math_pubs/40/
- Same authors, *The Probability of Backtest Overfitting* (SSRN 2326253): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2326253
- Bailey & López de Prado, *The Deflated Sharpe Ratio* (SSRN 2460551): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2460551
- Hsu & Kuan, *Re-Examining TA with White's Reality Check & Hansen's SPA* (SSRN 685361): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=685361
- *Backtest overfitting in the ML era* (Elsevier ESWA): https://www.sciencedirect.com/science/article/abs/pii/S0950705124011110
- Liu & Tsyvinski, *Risks and Returns of Cryptocurrency* (NBER w24877): https://www.nber.org/system/files/working_papers/w24877/w24877.pdf
- Liu/Tsyvinski/Wu, *Common Risk Factors in Cryptocurrency* (*Journal of Finance* 2022): https://onlinelibrary.wiley.com/doi/abs/10.1111/jofi.13119
- Han/Kang/Ryu, *TS & CS Momentum in Crypto under Realistic Assumptions* (SSRN 4675565): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4675565
- *Cryptocurrency momentum has (not) its moments* (*FMPM* 2025): https://link.springer.com/article/10.1007/s11408-025-00474-9
- *Funding Rate Arbitrage on CEX/DEX* (ScienceDirect S2096720925000818): https://www.sciencedirect.com/science/article/pii/S2096720925000818
- *Liquidity Shocks & Risk-managed Strategy: Bitcoin* (ScienceDirect S1042444X22000019): https://www.sciencedirect.com/science/article/abs/pii/S1042444X22000019
- Moreira & Muir, *Volatility-Managed Portfolios* (NBER w22208): https://www.nber.org/system/files/working_papers/w22208/w22208.pdf
- Binance Spot API — Filters: https://developers.binance.com/docs/binance-spot-api-docs/filters
- Binance Spot API — Rate Limits: https://developers.binance.com/docs/binance-spot-api-docs/rest-api/limits
- Binance Spot API — Trading Endpoints (idempotent / no disconnect cancel-all): https://developers.binance.com/docs/binance-spot-api-docs/rest-api/trading-endpoints
- freqtrade official documentation (Backtesting/Hyperopt/Lookahead/FreqAI): https://www.freqtrade.io/en/stable/backtesting/
- QuantConnect Reconciliation: https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/reconciliation
- GitHub maintenance status (verified via gh api): freqtrade / NautilusTrader / LEAN / vectorbt / backtrader repositories

### Medium (Reference Encyclopedias / Teaching Authorities / Broker Research)
- Wikipedia: Purged cross-validation / Deflated Sharpe ratio / Walk forward optimization
- Stefan Jansen, *ML for Trading*: https://stefan-jansen.github.io/machine-learning-for-trading/
- IBKR Quant — Walk-Forward: https://www.interactivebrokers.com/campus/ibkr-quant-news/the-future-of-backtesting-a-deep-dive-into-walk-forward-analysis/
- MLflow official documentation (Experiment Tracking / Registry): https://mlflow.org/classical-ml/experiment-tracking
- arXiv, *Nine Challenges in Modern Algorithmic Trading*: https://arxiv.org/pdf/2101.08813

### Low (⚠️ Vendor / Marketing Blogs — reference order-of-magnitude only; require independent verification)
- ⚠️ CoinAPI / StratBase (survivorship bias dead-coin percentages — data vendor blogs with commercial bias)
- ⚠️ BuildAlpha / QuantProof / StrategyQuant (Monte Carlo — tool-vendor advertorials)
- ⚠️ BitMEX funding rate 92% positive (financial media reprint — original research requires verification)
- ⚠️ All bot vendors / signal sellers / course sellers: **conclusions entirely disregarded**; any "best/must-have/recommended bot" language treated as unverified hypothesis

### ⚠️ Pollution Warning Summary
The crypto trading space is saturated with signal sellers, course vendors, profit-screenshot marketers, tool-vendor advertorials, and mutually mirrored aggregator sites. This report **uniformly downweights** all such sources. All strong claims are anchored to independently verifiable academic primaries and official exchange documentation. The specific numbers at three points — Monte Carlo, survivorship bias, and funding rates (58% dead coins / MDD 3× / 92% positive funding) — all come from low-credibility sources. **The directional claim is credible; exact values must be verified against your own data before use.**
