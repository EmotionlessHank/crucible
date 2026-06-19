# L-003: Survivorship bias inflates crypto backtests

**Tags**: `data` `backtest` `survivorship`
**Context**: Building historical datasets, especially for cross-sectional / multi-coin strategies.

## Symptom
Backtest returns look spectacular; live performance is far weaker.

## Root cause
Backtesting only coins alive today excludes the >50% that died/delisted. Exchanges often purge delisted pairs' klines, so dead history is invisible. This overstates returns systematically (reported ~3–4x in one altcoin example; exact figures from vendor blogs, direction reliable).

## Lesson / fix
- BTC-only start naturally avoids this; when expanding to multi-coin, source datasets that **include delisted pairs**.
- Verify your dataset has dead/delisted symbols before trusting cross-sectional results.
- Recompute any vendor-quoted inflation figure on your own data.

## Related
best-practices-research §1.3, §2.6
