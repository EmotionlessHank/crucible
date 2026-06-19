# EXCHANGE — operational SoT (Phase 2; identifiers only)

> Status: 🚧 TEMPLATE — fill at Phase 2 when a live exchange account exists. Identifiers only, NEVER credentials.

## Account
- Exchange: `{e.g. Binance}`
- Account / sub-account id: `{id}`
- Login: `{login email}`

## API access (pointers, not the keys)
- API key id / label: `{label}`  → actual key in `{secret store / .env var name}`
- Scopes: read + spot/futures trade · **withdrawal DISABLED**
- IP allowlist: `{egress ip}`

## Market / deploy
- Instruments: `{e.g. BTC/USDT perpetual}`
- Environment: testnet `{url}` / mainnet `{url}`
- Host / runner: `{where the bot runs}`

## Quota / limits
- Rate limits (weight / orders / WS): `{values}`
- Leverage cap (project rule): ≤ 2–3x

## Cost gates
- Satellite sleeve size: `{~1% of crypto net worth}`
- Kill switch: sleeve drawdown −50% → full stop  | status: `❌ not yet built`
- Per-strategy cap: ≤ 25–30% of sleeve | concurrent strategies ≤ 3

## Update triggers
- Changed API scopes / IP / keys → update "API access".
- Changed instrument / host / environment → update "Market / deploy".
- Hit a real rate limit / quota → record under "Quota / limits".
