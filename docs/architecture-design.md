# Crypto Swing Algo Culling Machine — Architecture Design

> Version: 2026-06-19 · Status: **Pending user confirmation → Phase 0 coding begins after confirmation**
> Companion: decision log in project memory; evidence in `docs/best-practices-research.md`
> One-line positioning: A Darwinian strategy-screening machine — continuously culling overfitting junk, letting only validated survivors graduate to real capital.

---

## 1. Design Philosophy (Locked)

- **Not "find a strategy" — operate an elimination mechanism.** The value lies in the credibility of the elimination mechanism itself, not in any single strategy.
- **Core-satellite barbell**: the core sleeve already holds BTC DCA/laddered buys (stable); this machine is the ~1% experimental satellite sleeve (high-odds bets). The real deliverable = credible strategies + a machine that doesn't deceive itself — not the 1% capital.
- **Fitness determines everything**: the machine hill-climbs toward its score. Set the score to "returns" → evolves cheaters; set it to "survive first, then risk-adjusted optimum" → evolves genuine edge.
- **Returns are an output, not an entry criterion**: 100%+ annualized is the expected output of "validated edge × leverage" — **never used as an admission gate**.
- **Config over code**: every knob you'd turn to iterate — strategy parameters and search spaces, validation thresholds, fitness weights, guardrails, data sources, cost model — lives in versioned **config files**, never in code. Fine-tuning a strategy/threshold/guardrail **must not require a code change or a redeploy**. Code holds only *logic* (algorithms, gate implementations); all *tunables* are config.
- **CLI-first**: the deliverable is a command-line tool (`crucible <command>`). It runs unattended on a server (cron/systemd) and is callable by AI agents — non-interactive, structured (`--json`) output, deterministic exit codes.
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

## 2.5 Interface & Configuration Architecture

### 2.5.1 Config-over-code

**Principle**: tune by editing config, never by editing code. Code is logic; config is everything tunable.

| In config (tunable, no redeploy) | In code (logic only) |
|---|---|
| Strategy parameters + hyperopt search spaces | Strategy algorithm (the IStrategy class) |
| Validation thresholds (DSR / PBO / OOS-ratio / embargo / MC) | Gate implementations (walk-forward, DSR, PBO…) |
| Fitness weights + penalties (Calmar weight, turnover/instability penalty) | The fitness scoring function |
| Admission-gate floors, guardrails (position cap, leverage cap, drawdown breaker, concurrency) | Guardrail enforcement logic |
| Data sources / timeframes / date ranges / cost model (fees, slippage, funding) | Data pipeline, cost-model engine |

- **Format**: **YAML** for crucible's own configs (comments let you record *why* a value was tuned — feeds the iteration journal). freqtrade keeps its native JSON where required, **generated/merged from** crucible config (single source of truth).
- **Layering + precedence**: `config/base.yaml` < `config/profiles/{dryrun,live}.yaml` < `config/strategies/<family>.yaml` < CLI `--set key=value` overrides. Highest wins.
- **Schema-validated, fail-fast**: configs are parsed into **Pydantic** models — an invalid/missing key errors immediately with a clear message. **No silent fallback to defaults** (silent fallback is exactly how strategies drift onto wrong settings).
- **Secrets stay out of config**: config references credentials by env-var name only; real secrets live in `.env` / a secret manager (ties to the `infra-config-sot` identifier≠secret rule).
- **Reproducibility**: every run snapshots its fully-resolved config into MLflow alongside code hash + seed — a result is always tied to the exact config that produced it.

### 2.5.2 CLI-first (thin CLI, fat core)

A single Typer entrypoint `crucible`; each subcommand maps to a pipeline stage:

| Command | Stage |
|---|---|
| `crucible data pull/update` | fetch & cache OHLCV / funding / markPrice |
| `crucible backtest --strategy X` | single backtest (in-sample) |
| `crucible optimize --strategy X` | hyperopt parameter search |
| `crucible validate --candidate C` | walk-forward + DSR + PBO + fitness → gate verdict |
| `crucible paper --strategy X` | dry-run forward test |
| `crucible live --strategy X` | live deploy (Phase 2; guardrailed) |
| `crucible loop` | run the inner self-iteration loop until budget/time |
| `crucible report` | culling report / journal summary |
| `crucible status` | active runs / state |

- **Agent- & server-friendly**: non-interactive (all inputs via flags/config, no prompts), `--json` structured output, **deterministic exit codes per failure class**, clean stdout/stderr logging; long-runners (`loop`, `live`) run under systemd/cron and are queryable via `status`.
- **Thin CLI, fat core**: the CLI is a thin wrapper over the `crucible/` Python package — the same functions are callable programmatically (by an agent or by tests), not only through the shell.

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
| CLI framework | **Typer** | Type-hint based, clean `--help`/`--json`, easy subcommands; thin wrapper over the core package (audit at feat time) |
| Config | **YAML + Pydantic** | YAML is comment-friendly for fine-tuning rationale; Pydantic gives schema validation + fail-fast (no silent fallback) |
| Execution loop core | **freqtrade** | Crypto-native, backtest/hyperopt/dry-run/live in one system, 51.6k★ active, GPL-3.0; its JSON config is generated from crucible YAML |
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
/Users/hang/AI/trading/                # repo: crucible
├── README.md  CLAUDE.md  pyproject.toml
├── config/                            # ALL tunables (config-over-code) — YAML, versioned
│   ├── base.yaml                      # defaults: data, cost model, validation thresholds, fitness weights, guardrails
│   ├── profiles/
│   │   ├── dryrun.yaml                # paper overrides
│   │   └── live.yaml                  # live overrides (secrets referenced by env-var NAME; none inside)
│   ├── strategies/
│   │   └── trend_following.yaml       # params + hyperopt search space for one family
│   └── freqtrade/                     # generated freqtrade JSON (merged from the above; gitignored if it embeds secrets)
├── crucible/                          # the library (fat core; CLI is a thin wrapper over this)
│   ├── cli.py                         # Typer entrypoint: data/backtest/optimize/validate/paper/live/loop/report/status
│   ├── config.py                      # Pydantic schema + layered loader (base<profile<strategy<--set)
│   ├── data/                          # data pull + point-in-time + cost model
│   ├── strategies/                    # strategy LOGIC (freqtrade IStrategy); params injected from config
│   │   └── trend_following.py
│   ├── research/                      # walk_forward · cpcv · deflated_sharpe · pbo · monte_carlo · fitness (§4)
│   ├── validation/admission_gate.py   # §6 admission gate (6 hard criteria)
│   ├── live/guardrails.py             # §7 guardrails (position / leverage / ladder / circuit breaker)
│   ├── ops/kill_switch.py             # heartbeat + disconnect-cancel
│   ├── journal/                       # trade log writer (§10 schema)
│   └── registry/                      # survivor registry (MLflow / SQLite)
├── docs/  scripts/  infra/  .githooks/  .claude/skills/
├── data/  mlruns/  journal/  registry/  # gitignored runtime artifacts
└── .progress/                         # local Chinese working notes (gitignored)
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

1. Skeleton: `pyproject.toml` + `crucible/` package + **Typer CLI** (`crucible/cli.py`) with command stubs + **Pydantic config schema & layered loader** (`crucible/config.py`) + `config/base.yaml`. Install freqtrade + MLflow + skfolio + typer + pydantic + pyyaml.
2. Config-first: define `config/base.yaml` (data, cost model, validation thresholds, fitness weights, guardrails) and `config/strategies/trend_following.yaml` (params + search space) — **all tunables here, none hardcoded**. freqtrade JSON generated from these.
3. Data: `crucible data pull` → BTC/USDT spot + perpetual historical OHLCV + funding (several years).
4. Strategy family ①: **trend following** (EMA crossover + ATR stop-loss + volatility-based sizing) — logic in `crucible/strategies/trend_following.py`, **params read from config**.
5. `crucible/research/walk_forward.py`: rolling walk-forward harness, reports concatenated OOS only (thresholds from config).
6. `crucible/research/deflated_sharpe.py` + `pbo.py`: minimum viable, attached to walk-forward output.
7. `crucible/research/fitness.py`: implement the §4 fitness (weights/penalties from config).
8. MLflow: log resolved-config + params / metrics / code hash / random seed for every run.
9. `crucible/journal/`: trade log schema persisted to disk.
10. `crucible paper`: attach strategy family ① and run dry-run.
11. `crucible report`: produce first "crucible report" — candidate count, survivor count, survivor fitness ranking (JSON + human output).

> Funding-rate harvesting (market-neutral) is strategy family ②, added in Phase 1 — it requires perpetuals + hedging, more complex than trend following; excluded from MVP.

---

## 14. Locked Decisions / Open Items / Risks

**Locked**:
- ✅ **Edge ramp-up order**: Phase 0 starts with trend following (directional); funding-rate harvesting (structural) joins in Phase 1.
- ✅ **Phase 2 uses perpetual contracts**: to support 2–3x leverage / short selling / funding-rate capture (trade-off: liquidation + funding risk; §7 guardrails must be in place).
- ✅ **Config-over-code**: all tunables in versioned YAML, schema-validated (Pydantic), no redeploy to fine-tune (§2.5.1).
- ✅ **CLI-first**: single `crucible` Typer CLI over a fat core package; non-interactive, `--json`, deterministic exit codes — server- and agent-friendly (§2.5.2).

**Open / Risks**:
- **DSR/PBO thresholds**: initial values need calibration with real data in Phase 1; may be too loose or too tight.
- **Statistical risk of the 1-month time-box**: historical walk-forward supplements statistical power, but 1 month of paper trading is still a thin sample — survivors that graduate should be flagged for potential "lucky pass."
- **Exchange account**: Phase 2 requires a Binance (or alternative) API key; configure per ops-security checklist at that time.
