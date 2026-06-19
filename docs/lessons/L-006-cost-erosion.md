# L-006: Fees + slippage + funding erode the thin crypto edge

**Tags**: `cost` `execution` `backtest`
**Context**: Backtesting and sizing any strategy; choosing trade frequency.

## Symptom
A strategy is profitable in a cost-free backtest but flat or negative once realistic costs are added.

## Root cause
Crypto swing edge is often only "a few bps" of raw signal. Real cost = fee + spread + slippage + perpetual funding (8h). High turnover eats the edge entirely; ~97% of retail day traders lose largely for this reason.

## Lesson / fix
- Model **all** costs in backtest: taker/maker fee, slippage, and perpetual **funding** (easy to forget, silently bleeds long holds).
- Prefer maker/limit on one side; control turnover. Swing over intraday for this reason.
- Rule of thumb: expected return must be ≥ 2–3× round-trip cost to survive live.

## Related
best-practices-research §1.4, §4.5 · architecture-design §9
