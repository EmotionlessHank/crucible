# Crypto Swing Algo Culling Machine — Architecture Design

> Version: 2026-06-19 (v2, post-review) · Status: revised per docs/reviews/REV-architecture-v1.md
> Companion: decision log in project memory; evidence in `docs/best-practices-research.md`
> One-line positioning: A Darwinian strategy-screening machine — continuously culling overfitting junk, letting only validated survivors graduate to real capital.

---

## 0. v2 Changelog

- **A** Anti-overfit enforcement made architectural: durable monotonic global-N counter; human-loop trial logging + attribution firewall; second permanently-locked vault; candidate lifecycle state machine in registry.
- **B** Single gate module: both §4 fitness and §6 admission import `crucible/validation/gates.py`; no re-implementation.
- **C** Admission gate collapsed from 6 to 4 criteria: removed dedup OOS≥IS×70% and rubber-stamp capacity; replaced capacity with modeled slippage-at-exit gate.
- **D** Auto-go-live replaced by human promote gate (`crucible live --confirm`) for first live deploy; diagram and §12 updated.
- **E** Graduation gate replaced 1-month calendar time-box with trade-count + volatility-cycle gate (≥30 independent trades AND ≥1 full vol cycle).
- **F** Funding modeled as sign-variable stochastic series in Monte Carlo; 8h assumption dropped; data caveat noted.
- **G** Added `crucible/live/reconciliation.py` module + markPrice vs lastPrice divergence noted.
- **H** freqtrade framed as execution-coupled but validation-agnostic; backtest-result dataclass defined; walk-forward harness noted as custom; version pinned.
- **I** Config-over-code clarified: no-code tuning is inner-loop only; YAML→JSON generator must validate against freqtrade schema; generated JSON always gitignored.
- **J** freqtrade lookahead-analysis noted as heuristic (false negatives/positives); CPCV + vault are the real anti-leakage line.
- **K** CPCV deferred to Phase 1+; MLflow Model Registry replaced by SQLite/JSON ledger; GA/recombine search replaced by grid/random + plateau check; dataset content hash added per run.
- **L** Phase 0 target revised to ~1-week E2E skeleton (AI-paced); walk-forward harness first; validation calibration continues into Phase 1.
- **M** §14 Locked Decisions updated: Non-EU/Binance perps confirmed; human promote gate; trade-count+vol-cycle gate; CPCV deferred; MLflow Registry→SQLite; GA→grid/random.

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
 │  Trade-log failure attribution (IS mechanics only) → you propose new edge hypothesis / strategy family → feed into inner loop  │
 │  Every human hypothesis (incl. rejected) logged in trial ledger and counted in global N                                        │
 └───────────────────────────────┬──────────────────────────────┘
                                 ▼
 ┌──────────────────── Inner loop (fast · fully automated) ──────────────────────┐
 │  ① Generate candidates (parameter variants; N counter incremented here) → ② Validation gates (kill overfitting)  │
 │       ▲                            │                                                                               │
 │       └──── ④ grid/random search ◀── ③ Select (keep survivors, rank by fitness) ──┘                              │
 └───────────────────────────────┬──────────────────────────────┘
                                 │ Survivors
                                 ▼
        ┌──── Admission gate (all 4 hard criteria passed) ────┐  ── fail ──▶ rework / eliminate
                                 ▼
                  Paper forward (dry-run) — trade-count + vol-cycle gate (≥30 trades, ≥1 vol cycle)
                                 ▼
                  human promote gate → laddered live (satellite sleeve)
                                 ▼
                  Trade log + MLflow Tracking → attribution → back to outer loop
```

Data layer and backtest layer run throughout; vault-style holdout is locked at all times — opened only once before the admission gate. A **second permanently-locked vault** remains sealed even after the first vault is opened (re-opt guard).

---

## 2.5 Interface & Configuration Architecture

### 2.5.1 Config-over-code

**Principle**: tune by editing config, never by editing code. Code is logic; config is everything tunable.

**Scope clarification**: no-code tuning applies to the **inner loop only** (parameter sweeps within a known strategy family). The **outer loop produces code** — new strategy families and regime gates require code changes. This is intentional and expected.

| In config (tunable, no redeploy) | In code (logic only) |
|---|---|
| Strategy parameters + hyperopt search spaces | Strategy algorithm (the IStrategy class) |
| Validation thresholds (DSR / PBO / OOS-ratio / embargo / MC) | Gate implementations (walk-forward, DSR, PBO…) — single source in `validation/gates.py` |
| Fitness weights + penalties (Calmar weight, turnover/instability penalty) | The fitness scoring function |
| Admission-gate floors, guardrails (position cap, leverage cap, drawdown breaker, concurrency) | Guardrail enforcement logic |
| Data sources / timeframes / date ranges / cost model (fees, slippage, funding) | Data pipeline, cost-model engine |

- **Format**: **YAML** for crucible's own configs (comments let you record *why* a value was tuned — feeds the iteration journal). freqtrade keeps its native JSON where required, **generated/merged from** crucible config (single source of truth). The YAML→freqtrade-JSON generator **validates output against freqtrade's JSON schema** before writing (freqtrade silently ignores unknown keys — validation catches drift). The generated JSON is **always gitignored** as a build artifact and must never be hand-edited.
- **Layering + precedence**: `config/base.yaml` < `config/profiles/{dryrun,live}.yaml` < `config/strategies/<family>.yaml` < CLI `--set key=value` overrides. Highest wins.
- **Schema-validated, fail-fast**: configs are parsed into **Pydantic** models — an invalid/missing key errors immediately with a clear message. **No silent fallback to defaults** (silent fallback is exactly how strategies drift onto wrong settings).
- **Secrets stay out of config**: config references credentials by env-var name only; real secrets live in `.env` / a secret manager (ties to the `infra-config-sot` identifier≠secret rule).
- **Reproducibility**: every run snapshots its fully-resolved config into MLflow alongside code hash + seed + **dataset content hash** (exchanges silently revise history; hash pins the exact data) — a result is always tied to the exact config and data that produced it.

### 2.5.2 CLI-first (thin CLI, fat core)

A single Typer entrypoint `crucible`; each subcommand maps to a pipeline stage:

| Command | Stage |
|---|---|
| `crucible data pull/update` | fetch & cache OHLCV / funding / markPrice |
| `crucible backtest --strategy X` | single backtest (in-sample) |
| `crucible optimize --strategy X` | grid/random parameter search |
| `crucible validate --candidate C` | walk-forward + DSR + PBO + fitness → gate verdict |
| `crucible paper --strategy X` | dry-run forward test |
| `crucible live --strategy X --confirm` | live deploy (Phase 2; human promote gate; guardrailed) |
| `crucible loop` | run the inner self-iteration loop until budget/time |
| `crucible report` | culling report / journal summary |
| `crucible status` | active runs / state |

- **Agent- & server-friendly**: non-interactive (all inputs via flags/config, no prompts), `--json` structured output, **deterministic exit codes per failure class**, clean stdout/stderr logging; long-runners (`loop`, `live`) run under systemd/cron and are queryable via `status`.
- **Thin CLI, fat core**: the CLI is a thin wrapper over the `crucible/` Python package — the same functions are callable programmatically (by an agent or by tests), not only through the shell.

---

## 3. Self-Iterating Two-Layer Loop (Mechanism Core)

### Inner Loop (fully automated, machine completes in hours)
Searches the parameter space **within a single strategy family**: generates hundreds to thousands of parameter variants via **grid/random search** (≤6 parameters per family — debuggable, no search-overfit surface) → each passes the validation gates → kills overfitting → continues searching in the neighborhood of survivors (= optimization). Engine: freqtrade hyperopt with grid/random spaces; parameter-plateau check required.

### Outer Loop (human-seeded, low frequency)
The inner loop can only refine known directions; new edge requires human injection. Driver = **trade-log failure attribution** (the machine tells you "trend strategy triggered chain stop-losses in a ranging market" → you propose "add ranging-regime gate" hypothesis → feed back into inner loop). The inspiration funnel enters here — treated as hypotheses, not finished products. **The outer loop produces code** (new IStrategy subclasses, new regime gates); it is not config-only.

### Survival Discipline (architectural, not honor-system)

1. **Vault-style holdout**: one segment of history locked permanently; the inner loop never touches it; opened only once before the admission gate — once seen, invalidated for re-opt. A **second permanently-locked vault** is maintained; once the first vault is opened, the second vault remains sealed for any subsequent re-optimization cycle.

2. **Global trial budget N — durable, monotonic, append-only counter**: N is persisted in the loop-state store and incremented **at candidate generation** (not at validation). Incrementing at generation means N cannot be under-counted even if the run crashes or parallel workers race. Under-counting N silently weakens DSR. The counter is append-only: it is never reset, never decremented, never overwritten.

3. **Human outer-loop is the dominant leak**: every human hypothesis — including rejected ones — must be logged into the trial ledger and counted in N. Global-N must include all human-seeded hypotheses, not only machine-generated candidates.

4. **Attribution firewall**: failure-attribution narratives (the text fed back to the human for outer-loop seeding) may cite only **in-sample trade-log mechanics** ("stops chained in low-volatility sideways action, trigger price was X"). They must never cite OOS or vault results. This is enforced by convention and code review — attribution outputs are produced from the trade-log schema (§10) only.

5. **Forward discipline**: true OOS always comes from future new data; after every re-optimization a paper forward period (trade-count + volatility-cycle gate, §6 criterion ③) must be completed before scaling up.

---

## 4. Fitness Function (The Global Linchpin)

Both the fitness function and the admission gate (§6) import the **single authoritative gate module** `crucible/validation/gates.py`. Neither re-implements the gate logic. This is enforced at code review: any duplicate gate implementation is a blocking defect.

```
fitness(strategy_candidate):
  # Hard gates: any failure → fitness = 0 (kill)
  # Gates imported from crucible/validation/gates.py — NOT re-implemented here
  if not gates.walk_forward_OOS_pass(candidate):     return 0
  if not gates.DSR_significant(candidate, global_N): return 0
  if not gates.PBO_pass(candidate):                  return 0
  if not gates.net_edge_positive(candidate):         return 0
  # Score after passing gates
  score = Calmar_OOS                   # annualized / max drawdown — rewards both return and drawdown control
  score -= parameter_instability_penalty  # spiky peaks penalized, plateaus rewarded
  score -= high_turnover_penalty          # cost erosion penalized
  return score
```

**The machine hill-climbs toward this score, not toward returns.** This is the fundamental guarantee that a fully automated machine does not evolve into a cheater.

---

## 5. Validation Gates (Executable Definitions + Initial Thresholds)

> Thresholds are starting points; fine-tune after calibration with historical data in Phase 1. All gate logic lives in `crucible/validation/gates.py`.

| Gate | Method | Initial Threshold | Mounted On |
|---|---|---|---|
| No lookahead | freqtrade lookahead-analysis (heuristic pre-filter) | must pass | freqtrade lookahead-analysis — **heuristic only**: checks only triggered trades; false negatives on custom price callbacks; false positives possible. Necessary, not sufficient — CPCV + vault holdout are the real anti-leakage line. |
| Out-of-sample | walk-forward (anchored/rolling) | OOS ≥ IS×70% | custom harness wrapping freqtrade (NOT native to freqtrade — see §8) |
| Luck-adjusted | Deflated Sharpe (global N, incl. human trials) | DSR > 0 and significant | custom implementation |
| Anti-overfitting | PBO (CSCV) | PBO < 0.5 (lower is better) | skfolio / custom implementation — **deferred to Phase 1+** for single-asset BTC (walk-forward + DSR + parameter-plateau + Monte Carlo carry the anti-overfit weight); skfolio `CombinatorialPurgedCV` ready when needed |
| Parameter robustness | plateau vs. spike (heatmap) | ±10% neighborhood performs similarly | custom build |
| Path risk | Monte Carlo / block bootstrap — **funding modeled as sign-variable stochastic series** (see §9) | 5th-percentile terminal value > 0, ruin < 1% | custom build |
| Net edge | realistic cost model | > 0 after fees + slippage + funding | freqtrade cost model |

---

## 6. Admission Gate (Phase 1 → Phase 2: all 4 hard criteria required before live capital)

All gate checks import `crucible/validation/gates.py` — no re-implementation here.

| # | Condition | Criterion |
|---|---|---|
| ① | Passes all validation gates | Section 5 in full (gates.py) |
| ② | Paper graduation | ≥30 independent paper trades AND ≥1 full volatility cycle (4–8 weeks), whichever is longer. "Independent trade" = non-overlapping position windows (overlapping positions do not double-count). ~1 month is the expected typical duration given near-daily trading and is the **minimum**, not the exit. Reconciliation deviation within threshold (see §7 sub-section). |
| ③ | Risk-adjusted hurdle met | OOS Calmar ≥ floor value (not a return floor) |
| ④ | Positive net edge after modeled slippage-at-exit | > 0 after all costs including **modeled slippage-at-exit under stressed order-book depth** (stop cascade scenario; BTC high average liquidity does not guarantee liquidity at the moment of a forced stop exit under 2–3x leverage) |

**Note: no "annualized ≥ X" criterion — intentional; prevents reopening the overfitting gate.**
**Note: OOS≥IS×70% is a validation gate in §5 and is not repeated here as a separate criterion.**

---

## 7. Launch Guardrails and Human Promote Gate

### 7.1 Automation boundary

- **Validation gates (§5) are the sole automated filter** up to and including paper graduation. Everything from candidate generation through paper graduation runs unattended.
- **First live deploy requires a human promote gate**: `crucible live --confirm` surfaces a summary of parameter drift across re-opt rounds and an economic-intuition note (why does this edge exist; is the regime likely to persist). The human reads this and types `--confirm`. This gate exists because a lucky-window survivor auto-deploying into the first regime shift — while laddering is still scaling in — is the realistic blow-up scenario for 1% satellite capital.
- After human promotion, all sizing, scaling, and hard-stop enforcement runs fully automated.

### 7.2 Hard guardrails (non-negotiable after promotion)

1. **Hard position cap per strategy** ≤ satellite sleeve 25–30%; **concurrent strategy count cap** (initial ≤3).
2. **Hard leverage cap** ≤2–3x (back-calculated from -50% drawdown tolerance).
3. **Laddered sizing**: first trade at minimum lot → live vs. backtest reconciliation consistent (see §7.3) → then auto-scale to target position.
4. **Satellite sleeve -50% full-stop circuit breaker** + per-strategy three auto-delisting triggers (drawdown exceeds threshold / drift / performance decay).
5. **Ops security**: API key withdrawal disabled + IP whitelist + `newClientOrderId` idempotency + custom kill switch (exchange provides no disconnect-cancel) + heartbeat alert (Telegram).

### 7.3 Backtest↔live reconciliation

Module: `crucible/live/reconciliation.py`. This module consumes the journal (§10 trade-log schema) and produces a **backtest↔live deviation number** on the metrics that admission criterion ② and the auto-delist trigger consume. Without this number, criterion ② ("reconciliation deviation within threshold") and the drift-based auto-delist trigger have no data to act on.

**Known divergence source — markPrice vs lastPrice**: freqtrade uses markPrice for signal triggers (index-smoothed, filters single-exchange wick spikes) but fills execute at lastPrice. This systematic spread is the largest built-in source of backtest↔live deviation and must be modeled in the reconciliation calculation.

---

## 8. Final Tech Stack (With Rationale)

**freqtrade coupling stance**: the system is **wedded to freqtrade for execution** (IStrategy subclasses, hyperopt, dry-run, live trading loop) and **engine-agnostic for validation**. Research and validation modules consume a `BacktestResult` dataclass (trades list, equity curve, run metadata / config hash) — they do not parse freqtrade output directly. This means the validation stack is replaceable even though strategies (IStrategy) are not.

**freqtrade version**: pin the exact version in `pyproject.toml` and `requirements.txt`. Output format and column names change across minor releases — unpinned freqtrade is a silent correctness hazard.

**Walk-forward harness**: the walk-forward engine is **NOT native to freqtrade** — it is custom subprocess orchestration that calls `freqtrade backtesting` across folds and stitches the OOS segments. This is the largest Phase-0 implementation cost and must be built first (end-to-end on a throwaway strategy) before DSR/PBO/fitness are wired in.

| Component | Choice | Rationale |
|---|---|---|
| Language | Python 3.11+ | Ecosystem |
| CLI framework | **Typer** | Type-hint based, clean `--help`/`--json`, easy subcommands; thin wrapper over the core package |
| Config | **YAML + Pydantic** | YAML is comment-friendly for fine-tuning rationale; Pydantic gives schema validation + fail-fast (no silent fallback) |
| Execution loop core | **freqtrade** (pinned version) | Crypto-native, backtest/hyperopt/dry-run/live in one system, 51.6k★ active, GPL-3.0; its JSON config is generated from crucible YAML and validated against freqtrade schema |
| Backtest result contract | `BacktestResult` dataclass | Decouples validation from freqtrade output format; engine-agnostic validation |
| Data / exchange access | freqtrade built-in (ccxt) + Binance official API | First-party OHLCV / funding rate / markPrice; exchange abstracted behind ccxt config — swappable to Bybit/OKX via config change |
| Parameter search | freqtrade hyperopt with **grid/random spaces** | ≤6 params per family; plateau check required; no GA/recombine (debuggability, no search-overfit surface) |
| CPCV / purge | **skfolio** `CombinatorialPurgedCV` — **deferred to Phase 1+** | Single-asset BTC: walk-forward + DSR + PBO + plateau + Monte Carlo carry anti-overfit weight; skfolio ready when needed |
| DSR / PBO | Custom implementation (~100 lines) | No mature off-the-shelf library; core logic is simple |
| Experiment tracking | **MLflow Tracking** | Each backtest = one run; records params / metrics / code hash / seed / dataset content hash; reproducible |
| Candidate/survivor ledger | **SQLite/JSON ledger** (lifecycle state machine) | Lifecycle states: generated→validated→paper-running→paper-passed→live; illegal transitions impossible; simpler and more auditable than MLflow Model Registry for this use case |
| Alerts | Telegram (freqtrade built-in) | telegram-mcp already available |

> backtrader is unmaintained (last real commit ~3 years ago) — not adopted. NautilusTrader / LEAN are future upgrade candidates ("stronger backtest-live engine consistency") — not introduced in MVP.

---

## 9. Data Layer Design

- **Source**: Binance official API first-party (spot + USDⓈ-M perpetuals); OHLCV + fundingRate + markPrice. User is Non-EU — Binance perpetuals are accessible with freqtrade's isolated margin mode. Exchange is abstracted behind ccxt config and is swappable to Bybit/OKX via a config change.
- **Survivorship bias**: single-asset BTC start naturally avoids it; when expanding to multiple assets, supplement with archived data including delisted pairs.
- **Quality**: point-in-time (signals use only fully closed candles); use markPrice rather than lastPrice for triggers — filters single-exchange wick spikes.
- **Cost model — funding**: perpetual funding is modeled as a **sign-variable stochastic series** in Monte Carlo. Funding flips sign (longs pay / receive; shorts receive / pay depending on market sentiment) — it is not a constant drag. Treating it as a fixed negative cost overstates the penalty in some regimes and understates it in others.
  - **Data caveat**: freqtrade backtest funding accuracy depends entirely on historical funding-rate data quality (gaps in exchange data = silent error). The funding interval is **variable** — the 8-hour assumption is stale (Binance issue #12583); do not hardcode 8h. Use the actual interval from the downloaded fundingRate data.
- **Dataset content hash**: every run records a content hash of the dataset files used (exchanges silently revise history). Hash pins the exact data for reproducibility — date range alone is insufficient.
- **Local cache**: freqtrade `download-data`, stored as parquet by timeframe.

---

## 10. Trade Log Schema (Per-Trade Required — For Attribution)

Signal timestamp and trigger conditions · expected price vs. actual fill price (→ realized slippage) · order type and state-machine trace · fees · position size · market-state snapshot at the time (volatility / spread / trend regime label) · strategy version hash · indicator values that drove the decision. **Key: per-trade "expected vs. actual" is what distinguishes strategy failure from execution failure.**

Attribution output (fed to the outer loop) must be derived exclusively from this schema — never from OOS or vault metrics (attribution firewall, §3).

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
│   │   └── trend_following.yaml       # params + grid/random search space for one family
│   └── freqtrade/                     # generated freqtrade JSON (always gitignored — build artifact, never hand-edited)
├── crucible/                          # the library (fat core; CLI is a thin wrapper over this)
│   ├── cli.py                         # Typer entrypoint: data/backtest/optimize/validate/paper/live/loop/report/status
│   ├── config.py                      # Pydantic schema + layered loader (base<profile<strategy<--set)
│   ├── data/                          # data pull + point-in-time + cost model + dataset content hashing
│   ├── strategies/                    # strategy LOGIC (freqtrade IStrategy); params injected from config
│   │   └── trend_following.py
│   ├── research/                      # walk_forward · deflated_sharpe · pbo · monte_carlo · fitness (§4)
│   │   └── backtest_result.py         # BacktestResult dataclass — contract between freqtrade and validation/research
│   ├── validation/
│   │   ├── gates.py                   # SINGLE AUTHORITATIVE GATE MODULE — imported by fitness (§4) and admission (§6); never duplicated
│   │   └── admission_gate.py          # §6 admission gate (4 hard criteria); imports gates.py
│   ├── vault/                         # vault module: mediates the single allowed read of vault-1; records open-event; refuses/warns on second access; vault-2 permanently sealed
│   ├── live/
│   │   ├── guardrails.py              # §7 guardrails (position / leverage / ladder / circuit breaker)
│   │   └── reconciliation.py          # backtest↔live deviation; markPrice-vs-lastPrice divergence; feeds admission ② and auto-delist trigger
│   ├── ops/kill_switch.py             # heartbeat + disconnect-cancel
│   ├── journal/                       # trade log writer (§10 schema); attribution firewall: output derived from trade log only
│   └── registry/                      # SQLite/JSON candidate lifecycle ledger (generated→validated→paper-running→paper-passed→live)
├── loop_state/                        # durable loop state: global-N counter (append-only, survives crash/parallel runs); human trial log
├── docs/  scripts/  infra/  .githooks/  .claude/skills/
├── data/  mlruns/  journal/  registry/  # gitignored runtime artifacts
└── .progress/                         # local working notes (gitignored)
```

---

## 12. Three-Phase Roadmap

| Phase | Content | Exit / Graduation Criterion |
|---|---|---|
| **Phase 0** Build the machine (~1 week E2E skeleton, AI-paced) | Build walk-forward harness **first** (end-to-end on a throwaway strategy) → then wire DSR/PBO/fitness → data → backtest → paper. "E2E skeleton runs" ≠ "validation fully calibrated" — validation depth and threshold calibration continues into Phase 1. | First complete closed loop runs end-to-end |
| **Phase 1** Paper self-iteration | Fully automated crucible; statistical power from historical walk-forward/DSR/PBO/parameter-plateau/Monte Carlo; paper graduation by trade-count + vol-cycle gate; threshold calibration with real data | ≥1 strategy passes all 4 admission criteria → Phase 2; **zero pass → post-mortem: methodology problem or edge genuinely unreachable** |
| **Phase 2** Live capital (1% satellite sleeve) | Human promote gate (`crucible live --confirm`) → laddered sizing → hard guardrails; reconciliation running | **Satellite sleeve -50% → full stop + post-mortem** |

---

## 13. Phase 0 MVP Delivery Checklist (Start Here After Confirmation)

1. Skeleton: `pyproject.toml` + `crucible/` package + **Typer CLI** (`crucible/cli.py`) with command stubs + **Pydantic config schema & layered loader** (`crucible/config.py`) + `config/base.yaml`. Pin freqtrade version. Install freqtrade + MLflow + skfolio + typer + pydantic + pyyaml.
2. Config-first: define `config/base.yaml` (data, cost model, validation thresholds, fitness weights, guardrails) and `config/strategies/trend_following.yaml` (params + grid/random search space) — **all tunables here, none hardcoded**. freqtrade JSON generated from these and schema-validated; gitignored.
3. Data: `crucible data pull` → BTC/USDT spot + perpetual historical OHLCV + funding (several years). Record dataset content hash per pull.
4. Strategy family ①: **trend following** (EMA crossover + ATR stop-loss + volatility-based sizing) — logic in `crucible/strategies/trend_following.py`, **params read from config**.
5. **`crucible/research/walk_forward.py`** (build first, on throwaway strategy): custom subprocess harness orchestrating freqtrade backtesting across folds; stitches OOS segments; reports concatenated OOS only. This is the largest Phase-0 cost.
6. `BacktestResult` dataclass (`crucible/research/backtest_result.py`): contract between freqtrade output and all validation/research modules.
7. `crucible/validation/gates.py`: single authoritative gate module — walk-forward OOS pass, DSR (global N), PBO, net edge.
8. `crucible/research/deflated_sharpe.py` + `pbo.py`: minimum viable, consuming BacktestResult; DSR uses global N from loop-state store.
9. `crucible/research/fitness.py`: implement the §4 fitness; imports gates.py (no re-implementation).
10. Durable loop state: `loop_state/` store with append-only global-N counter + human trial ledger.
11. MLflow Tracking: log resolved-config + params / metrics / code hash / seed / dataset content hash for every run.
12. `crucible/journal/`: trade log schema persisted to disk; attribution output restricted to trade-log fields.
13. `crucible/registry/`: SQLite/JSON lifecycle ledger with state machine (generated→validated→paper-running→paper-passed→live).
14. `crucible paper`: attach strategy family ① and run dry-run.
15. `crucible report`: produce first "crucible report" — candidate count, survivor count, survivor fitness ranking (JSON + human output).

> Funding-rate harvesting (market-neutral) is strategy family ②, added in Phase 1 — it requires perpetuals + hedging, more complex than trend following; excluded from MVP.

---

## 14. Locked Decisions / Open Items / Risks

**Locked**:
- ✅ **Edge ramp-up order**: Phase 0 starts with trend following (directional); funding-rate harvesting (structural) joins in Phase 1.
- ✅ **Phase 2 uses perpetual contracts**: to support 2–3x leverage / short selling / funding-rate capture (trade-off: liquidation + funding risk; §7 guardrails must be in place).
- ✅ **Config-over-code**: all tunables in versioned YAML, schema-validated (Pydantic), no redeploy to fine-tune (§2.5.1). Inner-loop only; outer loop produces code.
- ✅ **CLI-first**: single `crucible` Typer CLI over a fat core package; non-interactive, `--json`, deterministic exit codes — server- and agent-friendly (§2.5.2).
- ✅ **Non-EU / Binance perps confirmed**: freqtrade isolated margin works; exchange abstracted behind ccxt config and swappable to Bybit/OKX via config.
- ✅ **Human promote gate for first live deploy**: `crucible live --confirm` surfaces parameter drift + economic-intuition note; human must confirm. Everything up to paper graduation is fully automated.
- ✅ **Trade-count + vol-cycle graduation gate**: ≥30 independent paper trades AND ≥1 full volatility cycle (4–8 weeks); ~1 month is expected minimum given near-daily trading, not a fixed exit.
- ✅ **CPCV deferred to Phase 1+**: single-asset BTC relies on walk-forward + DSR + PBO + parameter-plateau + Monte Carlo; skfolio `CombinatorialPurgedCV` ready for multi-asset Phase 1+.
- ✅ **MLflow Model Registry → SQLite/JSON lifecycle ledger**: candidate state machine is the load-bearing primitive; MLflow Tracking kept for reproducibility.
- ✅ **GA/recombine search → grid/random + parameter-plateau check**: ≤6 params per family; debuggable; avoids search-overfit surface.

**Open / Risks**:
- **DSR/PBO thresholds**: initial values need calibration with real data in Phase 1; may be too loose or too tight.
- **Graduation gate sample size**: ≥30 trades improves on the calendar time-box but remains a thin sample for low-frequency strategies; survivors that graduate should be flagged for potential "lucky pass" and monitored under laddered sizing.
- **Exchange account**: Phase 2 requires a Binance (or alternative) API key; configure per ops-security checklist at that time.
- **Funding data gaps**: historical fundingRate data from Binance may have gaps or revisions; gap handling policy needed in the data pipeline.
