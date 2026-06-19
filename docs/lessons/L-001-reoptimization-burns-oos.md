# L-001: Auto re-optimization burns out-of-sample into in-sample

**Tags**: `overfitting` `validation`
**Context**: Whenever the self-iterating loop re-optimizes parameters on freshly arrived data.

## Symptom
Strategies that pass validation keep degrading live; each re-optimization looks great in backtest but fails forward.

## Root cause
Every re-optimization run looks at the out-of-sample window again. Repeatedly tuning against it turns OOS into de-facto in-sample — the validation no longer measures generalization. The self-iteration machine becomes a self-deception machine.

## Lesson / fix
- Keep a **vault holdout** the loop never touches; look at it exactly once, right before graduation; then it is spent.
- Count a **global trial budget N** across all iterations; deflate Sharpe (DSR) with that global N, not per-round N.
- True OOS always comes from **future new data**; after any re-opt, force a fresh paper-forward window before sizing up.
- Reject any iteration whose PBO is too high.

## Related
best-practices-research §2.7 · architecture-design §3 (保命纪律) · [[L-004-return-selection-trap]]
