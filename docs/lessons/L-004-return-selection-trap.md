# L-004: Selecting strategies by backtest return picks noise

**Tags**: `overfitting` `selection` `validation`
**Context**: Choosing which candidate strategies to promote / deploy.

## Symptom
The "best" backtest (highest return / Sharpe) consistently disappoints live.

## Root cause
Across many trials, the highest backtest return is almost always the luckiest noise. Empirically, backtest Sharpe correlates ~0.05 with live results. A return threshold as a gate selects exactly the most overfit candidates.

## Lesson / fix
- Selection is a **funnel**: (1) hard gate on validation survival (walk-forward OOS, DSR, PBO, parameter plateau); (2) rank survivors by **Calmar** (rewards return AND drawdown control); (3) raw return only as a final tiebreaker.
- **Never** use a return threshold for admission. 100%+ annual is an outcome of (validated edge × leverage), not an entry criterion.
- Expect live return to shrink 20–50% vs backtest even after passing.

## Related
best-practices-research §0.5, §4.6 · architecture-design §4, §6 · [[L-001-reoptimization-burns-oos]]
