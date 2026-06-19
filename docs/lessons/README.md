# Lessons — AI retrieval tag map

> Gotchas hit on crucible, distilled into **atomic, tagged, retrievable** lessons. With the RAG protocol
> below, load only what the current task matches — don't read the whole库, save context.

## 🤖 AI protocol (read before working — but **only this file**)

1. **Before working**: scan the Tags column below; match current-task keywords (stack / action / object) against tags.
2. **Hit criterion**: a tag word merely overlapping is NOT a hit — the lesson's concrete symptom must match the task. Then read that `L-NNN` (usually 1–3).
3. **No hit**: do NOT open L files; just proceed (save context).
4. **New gotcha**: after fixing, add an `L-NNN` file + one row here (incrementing, no reuse, no gaps).
5. Location: this is the retrieval layer over `docs/best-practices-research.md` (full discussion lives there; this only routes).

## Tag vocabulary (project-specific)

> Only tags with at least one L behind them (empty tags cause failed lookups).

`overfitting` `validation` `selection` · `backtest` `data` `survivorship` `repainting` · `cost` `execution` `exchange` `ops` `idempotency` · `leverage` `risk` `regime` · `deploy` `git` `account`

## Lesson map

| ID | Tags | One-liner (read on match) |
|---|---|---|
| [L-001](L-001-reoptimization-burns-oos.md) | `overfitting` `validation` | Auto re-optimizing on fresh data repeatedly consumes the out-of-sample window — it silently becomes in-sample. |
| [L-002](L-002-public-scripts-repaint.md) | `backtest` `repainting` `data` | 95%+ public TradingView scripts repaint; treat any external strategy as a hypothesis, never a product. |
| [L-003](L-003-survivorship-bias.md) | `data` `backtest` `survivorship` | Backtesting only coins alive today overstates returns ~3–4x; include delisted/dead pairs. |
| [L-004](L-004-return-selection-trap.md) | `overfitting` `selection` `validation` | Selecting strategies by backtest return picks the luckiest noise (return↔live corr <0.05). Gate on survival, rank by Calmar. |
| [L-005](L-005-exchange-no-deadman-switch.md) | `execution` `exchange` `ops` `idempotency` | Binance spot API won't auto-cancel on disconnect — build your own kill switch + use `newClientOrderId` for idempotency. |
| [L-006](L-006-cost-erosion.md) | `cost` `execution` `backtest` | Fees + slippage + funding silently erode the thin crypto edge; high turnover eats it entirely. Model all costs. |

---
*Backfill continuously: one entry per gotcha.*
