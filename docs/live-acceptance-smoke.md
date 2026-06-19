# Live Acceptance Smoke (trading-adapted)

> Static green ≠ live green. typecheck/build/unit tests cannot catch the bug class that kills a money-handling
> bot: lifecycle leaks, reconnection, exchange outages, rate limits, timeouts, duplicate fills. Catch these with
> a real-environment smoke pass. Discipline now; runnable `scripts/smoke.sh` is written when Phase 2 live code exists.

## Self-verify first (mandatory)

Before claiming "cannot verify / needs manual acceptance", exhaust self-verification:
deployed endpoint to hit, local creds to reach the real exchange (testnet/dry-run), an existing smoke script.
The ACCEPTANCE checklist keeps only what genuinely depends on a human (real funded account, cross-device timing).
Auto-decidable things are never outsourced to a person. When debugging, **reproduce before fixing**.

## Edge probes ↔ bug class (each probe targets one class)

| Probe | How | Bug class it catches |
|---|---|---|
| **Reconnect** | Kill the WS/data feed mid-stream | Orders/positions left unmanaged; no kill switch (see [[L-005-exchange-no-deadman-switch]]) |
| **Duplicate order** | Retry the same order under simulated network failure | Non-idempotent ordering → double fills (needs `newClientOrderId`) |
| **Exchange outage** | Point at testnet with API erroring / 5xx / 429 | No safe-mode / no backoff → runaway retries, IP ban |
| **Timeout** | Lower order/ack timeout to force the watchdog branch | Timeout fallback path untested → stuck or duplicated state |
| **Reconciliation drift** | Run live alongside a parallel OOS backtest | Live equity diverges from model → execution/cost mismatch |

## Rules

- **Deterministic → auto-assert** (HTTP code, order state, log sentinel). **Uncertain → explicit manual checklist; never fake-green.**
- **Probe ↔ bug class one-to-one**; no aimless requests.
- **Secrets**: only withdrawal-disabled, IP-allowlisted keys; never log keys (grep logs for sentinels after a run).
- **Caught a bug → distill it** into an `L-NNN` (pairs with lessons-rag: smoke discovers, lessons-rag records).

## Phase 2 TODO
- Write `scripts/smoke.sh` against the live execution layer; deploy script prints "ping + smoke + log-sentinel grep".
