# L-002: Public TradingView scripts repaint

**Tags**: `backtest` `repainting` `data`
**Context**: Sourcing strategy ideas from TradingView / public scripts / sold signals.

## Symptom
A script's historical chart looks flawless, but live signals "evaporate" or fire differently than the backtest showed.

## Root cause
95%+ of public scripts repaint: they recalculate historical signals as new ticks arrive. On historical bars values look fixed; in real time the current bar mutates until close, creating ghost signals that never existed live. Public high-rated strategies are also already overfit or already arbitraged away.

## Lesson / fix
- Treat any external strategy as a **hypothesis to be falsified**, never a finished product.
- Re-implement and re-test on your own point-in-time data; use `barstate.isconfirmed`-equivalent (only closed bars).
- TradingView belongs in the **idea funnel**, not in the strategy-source stage.

## Related
best-practices-research §1.5, §2.6 · [[L-004-return-selection-trap]]
