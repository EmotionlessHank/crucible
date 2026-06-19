# crucible — Roadmap (Milestones & Tasks)

> The backbone above individual DDs. Derived from `architecture-design.md` (v2).
> `feat` picks a task here → writes a DD under `docs/designs/<ID>/` → `autopilot` implements → this file's
> task status + milestone progress is updated. This is the single progress ledger.

**Status legend**: ⬜ todo · 🟦 in-progress · ✅ done · ⏸️ blocked · ⏭️ deferred
**Each task** links to the architecture section it realizes and (once started) its DD folder.

---

## Milestone M0 — Phase 0: end-to-end skeleton (target: ~1-week E2E, AI-paced)

Goal: the culling loop runs end-to-end on ONE strategy on paper, producing a first crucible report.
"E2E runs" ≠ "validation calibrated" — threshold calibration continues in M1.
**Build order matters**: the walk-forward harness (T0.5) is the iceberg — build it early on a throwaway strategy.

| Task | Description | Arch ref | Status | DD |
|---|---|---|---|---|
| T0.1 | Project skeleton: `pyproject.toml`, `crucible/` package, **Typer CLI** (`cli.py`) with command stubs, entry point | §2.5.2, §11 | ⬜ | — |
| T0.2 | Config system: **Pydantic** schema + layered loader (base<profile<strategy<`--set`); `config/base.yaml` + `config/strategies/trend_following.yaml`; YAML→freqtrade-JSON generator **with schema validation** | §2.5.1 | ⬜ | — |
| T0.3 | Data layer: `crucible data pull` (Binance OHLCV + funding + markPrice via freqtrade/ccxt); point-in-time; **dataset content hash**; parquet cache | §9 | ⬜ | — |
| T0.4 | `BacktestResult` dataclass + freqtrade backtest wrapper (subprocess, parse output; **pin freqtrade version**) | §8 | ⬜ | — |
| T0.5 | **Walk-forward harness** (build early): rolling/anchored folds orchestrating freqtrade backtest, concatenate OOS only | §5 | ⬜ | — |
| T0.6 | Strategy family ① **trend-following** (EMA cross + ATR stop + vol sizing); logic in code, **params from config** | §13, best-practices §1 | ⬜ | — |
| T0.7 | **Single gate module** `validation/gates.py`: walk-forward OOS gate + net-edge gate (DSR/PBO wired here) | §4, §5, §6 | ⬜ | — |
| T0.8 | **DSR + PBO** implementations wired into gates; **durable global-N counter** (SQLite, incremented at candidate generation) | §3, §5 | ⬜ | — |
| T0.9 | **Vault** module: holdout split + single-read mediation + second permanently-sealed vault | §3 | ⬜ | — |
| T0.10 | **Fitness** function (imports gates; Calmar + penalties from config) | §4 | ⬜ | — |
| T0.11 | **MLflow Tracking**: snapshot resolved-config + params/metrics/code-hash/seed/dataset-hash per run | §2.5.1, §8 | ⬜ | — |
| T0.12 | **Trade journal** writer (§10 schema) | §10 | ⬜ | — |
| T0.13 | **Candidate lifecycle registry** (SQLite ledger: states + legal transitions) | §3, §8 | ⬜ | — |
| T0.14 | `crucible paper` dry-run wiring for strategy ① | §2.5.2, §12 | ⬜ | — |
| T0.15 | `crucible report` — culling report (candidate/survivor counts, fitness ranking), `--json` + human | §2.5.2 | ⬜ | — |

**M0 exit criterion**: `crucible` runs data → optimize (grid/random) → validate → fitness → report end-to-end on trend-following, with a dry-run running, and produces the first crucible report. ⬜

---

## Milestone M1 — Phase 1: paper self-iteration + validation calibration (time-box: graduation by trade-count gate, ~1 month typical)

Goal: run the automated crucible on paper; calibrate the gates on real history; graduate ≥1 strategy — or post-mortem.

| Task | Description | Arch ref | Status | DD |
|---|---|---|---|---|
| T1.1 | Calibrate DSR / PBO / parameter-plateau thresholds on real historical data | §5 | ⬜ | — |
| T1.2 | Inner-loop driver `crucible loop` (until budget/time) + **loop-state store** + `crucible status` | §3, §2.5.2 | ⬜ | — |
| T1.3 | Outer-loop tooling: **human hypothesis ledger** (counted in global N) + **attribution firewall** (IS-only outputs) | §3 | ⬜ | — |
| T1.4 | **Trade-count + vol-cycle graduation gate** enforcement (≥30 independent trades AND ≥1 vol cycle) | §6, §12 | ⬜ | — |
| T1.5 | **Monte Carlo** path risk incl. **sign-variable funding**; ruin<1% sizing | §4, §5, §9 | ⬜ | — |
| T1.6 | Strategy family ② **funding-rate harvesting** (perps + hedge) | §13, best-practices §1 | ⬜ | — |
| T1.7 | (when multi-asset) **CPCV + purge + embargo** via skfolio | §5 | ⏭️ | — |

**M1 exit criterion**: ≥1 strategy passes the 4-criterion admission gate via the trade-count gate → eligible for M2; OR documented post-mortem (methodology vs edge-unreachable). ⬜

---

## Milestone M2 — Phase 2: live (1% satellite sleeve, human-promote-gated)

Goal: graduated survivor runs on real capital with the human promote gate, hard guardrails, and reconciliation.

| Task | Description | Arch ref | Status | DD |
|---|---|---|---|---|
| T2.1 | Live **guardrails**: position cap, leverage cap ≤2–3x, laddered sizing, −50% breaker, auto-delist triggers | §7.2 | ⬜ | — |
| T2.2 | **Human promote gate** `crucible live --confirm` (surfaces param-drift across re-opt rounds) | §7.1 | ⬜ | — |
| T2.3 | **reconciliation.py**: parallel OOS-backtest vs live; markPrice/lastPrice divergence; feeds admission ② + auto-delist | §7.3 | ⬜ | — |
| T2.4 | Ops / **kill switch**: heartbeat, disconnect-cancel, idempotent `newClientOrderId`, API-key safety (withdrawal off + IP allowlist) | §7.2, lessons L-005 | ⬜ | — |
| T2.5 | **Exchange abstraction** via ccxt (Binance perps; swappable to Bybit/OKX) | §8, §14 | ⬜ | — |

**M2 exit criterion**: a survivor runs live on the 1% sleeve with reconciliation active and all guardrails enforced; money-box −50% breaker armed. ⬜

---

## How feat/autopilot use this file (protocol)

1. Pick the next ⬜ task (respect M0 build order — T0.5 walk-forward early).
2. `feat` → research + grill + write DD into `docs/designs/<ID>/`; set the task 🟦 and fill its DD link here.
3. `autopilot` → implement + review + verify.
4. On completion: set the task ✅; when all of a milestone's tasks are ✅ and its exit criterion is met, mark the milestone ✅ and record the date + key commits here.
5. New gotchas → `docs/lessons/` (L-NNN); new scope → add a task row (don't silently expand a DD).
