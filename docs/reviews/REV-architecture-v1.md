# Architecture Review v1 — crucible

> Date: 2026-06-19 · Independent review by 3 agents (architect / critic / feasibility), no self-review.
> Target: `docs/architecture-design.md` (pre-Phase-0 spec; no code yet).
> Verdicts: architect **sound-with-changes** · critic **REVISE** · feasibility **feasible-with-changes**.
> Consensus: the design philosophy and validation core are excellent and faithful to the research; ship it,
> but several anti-self-deception guarantees are honor-system rules, not enforced invariants, and two real-world
> constraints (EU/Binance margin, Phase-0 timeline) must be resolved.

## 🔴 Must-fix before building (cheap, load-bearing — protect the moat)

1. **Anti-overfit enforcement substrate** (architect-C1, critic-C2). The disciplines are stated as behaviors with no owning module. Build:
   - Durable, monotonic, append-only **global-N counter**, incremented at candidate generation (survives crash/parallel runs). Under-counting N silently *weakens* DSR.
   - **`vault` module** mediating the single allowed read, recording the open-event, refusing/loudly-warning on second access (physically segregated data).
   - **Candidate lifecycle state machine** in the registry (generated→validated→paper-running→paper-passed→live) so illegal transitions (e.g. `live` without paper-passed) are impossible.
2. **Human-loop leak (critic-C2, the deepest finding).** The dominant leak is the *human* outer loop: you read OOS failure → propose a new hypothesis informed by OOS → OOS info launders into the next IS design. Global-N counts machine trials only. Fix:
   - Log **every human hypothesis (incl. rejected)** into the trial ledger; inflate DSR's N with them.
   - **Attribution firewall**: failure-attribution narratives may cite only *IS trade-log mechanics* ("stops chained in low vol"), never OOS/vault results.
   - A **second permanently-locked vault** so a once-opened vault doesn't leave you blind on re-opt.
3. **Single authoritative gate module** (architect-M2, critic-M2). Fitness (§4) embeds the hard gates AND admission (§6①) re-checks them → drift risk. Both must import one `validation/gates.py`; neither re-implements.
4. **Replace the 1-month calendar time-box with a trade-count + vol-cycle gate** (critic-C3). Swing on 1 month = a handful of trades; DSR/PBO on that is noise. Gate: **≥30 independent paper trades AND ≥1 full vol cycle (4–8 wks)**, whichever is longer; 1 month is the *minimum*, never the exit. Define "independent trade" (overlapping positions inflate counts).
5. **Phase-0 timeline is 3–4x optimistic** (feasibility). Realistic solo estimate **4–7 weeks**. The walk-forward harness (NOT native to freqtrade — custom subprocess orchestration across folds) is the iceberg; build it first, end-to-end on a throwaway strategy, before DSR/PBO/fitness.
6. **Confirm Binance jurisdiction NOW** (feasibility, ❌ potential Phase-2 dead-end). freqtrade supports **isolated margin only**; EU/MiCA users can access Binance perps only via cross-margin "Credit Trading Mode" → freqtrade can't drive it. If EU-resident, re-target Bybit/OKX. Abstract the exchange behind ccxt config either way.

## 🟠 Should-fix (correctness + design honesty)

7. **Auto-go-live contradicts our own research** (critic-C1). Research says go-live must be a manual checkpoint; §7.1/§12 fully automate it. The realistic blow-up: lucky-window survivor auto-deploys → first regime shift → bleeds *while laddering is still scaling in* → breaker fires on money automation just funded. (User chose full-auto knowingly for 1% tuition — see Open Decisions.)
8. **Funding = sign-variable risk, not a constant cost** (critic-M1). Model funding as a stochastic, sign-flipping series in Monte Carlo. Also: freqtrade backtest funding is only as good as historical funding data (gaps), and "8h funding" is stale — Binance funding interval is now variable (issue #12583).
9. **Backtest↔live reconciliation has no module** (architect-§5) though admission ③ and a takedown trigger depend on it. Add `live/reconciliation.py` + journal→comparison data path. Also handle the built-in **markPrice (signal) vs lastPrice (fill) divergence**.
10. **Capacity gate is a rubber stamp** (critic-M3). "BTC liquidity — naturally satisfied" disables the gate; under 2–3x leverage + laddering + a stop cascade is exactly when slippage explodes. Gate on **modeled slippage-at-exit under stressed depth**.
11. **freqtrade coupling honesty** (architect-§2). Reframe: "wedded to freqtrade for *execution*; engine-agnostic for *validation*." Define a **backtest-result dataclass** (trades, equity curve, metadata) that research/validation consume, so the engine is replaceable even though strategies aren't. **Pin the freqtrade version** (output-parsing brittleness across versions).
12. **Config-over-code honesty** (architect-§4). No-code tuning applies to the **inner loop only**; the outer loop produces *code* (new strategy families / regime gates). YAML→freqtrade-JSON generator must **validate output against freqtrade's schema** (it silently ignores unknown keys) and the generated JSON must be **always gitignored** as a build artifact (never hand-edited).
13. **lookahead-analysis is heuristic, not a guarantee** (feasibility). It only checks triggered trades (false negatives) and false-positives on custom price callbacks. Keep CPCV + vault holdout as the real anti-leakage line; treat the freqtrade check as a cheap pre-filter.

## 🟡 Right-size / cut (over-engineering for a 1%-capital solo experiment)

14. **Defer CPCV** to multi-asset / Phase 1+ (architect + critic). For single-asset BTC, anchored walk-forward + DSR + PBO + parameter-plateau + Monte Carlo carry most of the anti-overfit weight. (skfolio `CombinatorialPurgedCV` confirmed available when needed.)
15. **Cut MLflow Model Registry → SQLite/JSON ledger**; keep MLflow **Tracking** (reproducibility is load-bearing). The lifecycle state machine (item 1) matters more than the tool.
16. **Cut GA/recombine search → grid/random + plateau check** for ≤6 params on one family (debuggable, no search-overfit surface).
17. **Collapse the 6 admission criteria to 4** (dedup ② OOS-ratio, already a validation gate, and ⑥ capacity, currently a rubber stamp).

## Open Decisions (need the user)

- **D1 Jurisdiction/exchange**: EU/MiCA resident? (determines whether Binance perps work with freqtrade; else Bybit/OKX).
- **D2 Phase-0 timeline**: accept the realistic 4–7 weeks (vs the aspirational 1–2)?
- **D3 Auto-go-live**: keep full-auto (1% tuition, knowingly) vs add a lightweight human "promote" gate vs a stricter min-size "live probation" before laddering.
- **D4 Graduation gate**: replace the 1-month time-box with the trade-count + vol-cycle gate?

## What must NOT be cut
no-return-floor rule · fitness = survival-then-Calmar · vault holdout · global-N (now incl. human trials) · Monte-Carlo ruin<1% sizing · the §7.6 ops-security checklist (the one place cutting corners loses real money).

## Sources (feasibility, first-party)
freqtrade: [leverage](https://www.freqtrade.io/en/stable/leverage/) · [lookahead-analysis](https://www.freqtrade.io/en/stable/lookahead-analysis/) · [hyperopt](https://www.freqtrade.io/en/stable/hyperopt/) · [data-download](https://www.freqtrade.io/en/stable/data-download/) · issues [#10503 EU cross-margin](https://github.com/freqtrade/freqtrade/issues/10503) · [#12583 funding intervals](https://github.com/freqtrade/freqtrade/issues/12583) · [#11346 lookahead limits](https://github.com/freqtrade/freqtrade/issues/11346) · [skfolio CombinatorialPurgedCV](https://skfolio.org/generated/skfolio.model_selection.CombinatorialPurgedCV.html) · [timeseriescv](https://github.com/sam31415/timeseriescv)
