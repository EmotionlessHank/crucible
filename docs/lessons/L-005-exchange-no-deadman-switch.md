# L-005: Exchange has no dead-man's-switch — build your own

**Tags**: `execution` `exchange` `ops` `idempotency`
**Context**: Building the live execution / ops layer (Phase 2) against Binance.

## Symptom
On a disconnect or crash, open orders/positions are left unmanaged; network retries cause duplicate fills.

## Root cause
Binance Spot API provides **no** server-side cancel-on-disconnect (no dead-man's-switch / `cancelAllAfter`). Naive retry logic re-sends orders, double-filling.

## Lesson / fix
- Build a local **kill switch**: on heartbeat loss / anomaly over threshold → cancel-all + stop opening.
- Make every order **idempotent** with a client-generated unique `newClientOrderId`; reuse the same id on retry.
- API keys: **withdrawal-disabled** + IP allowlist. Reconnect → reconcile against the exchange (real positions/orders) before resuming.

## Related
best-practices-research §4.1, §4.4 · architecture-design §7
