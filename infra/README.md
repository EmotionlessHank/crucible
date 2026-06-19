# infra — operational config single source of truth

> One live doc per cloud/service for **operational config** (account / deploy / quota / cost-gate).
> Identifiers only — **never credentials**. This makes the doc safe to commit and hand over.

## Identifier ≠ secret (the core rule)

| Goes in `infra/<SERVICE>.md` (identifiers, pointers) | NEVER here (credentials, stored elsewhere) |
|---|---|
| project id / account id / billing id | API key / secret key / token |
| service-account email / IAM role | `*.json` / `*.p8` / private keys |
| service name / region / URL | passwords in connection strings |
| quota values / budget thresholds | webhook signing secrets |

> Test: if leaking it **cannot** be used to call your service → identifier (write it). If it can → secret (store elsewhere).

Real credentials live in a secret manager or a gitignored `.env` (see project `.gitignore` + `.githooks/pre-commit`).
This doc only records **which credential, rotated where**.

## Files
- `EXCHANGE.md` — template skeleton; fill with Binance (or chosen exchange) identifiers at **Phase 2**.

## Maintenance SOP (registered in CLAUDE.md)
After changing any service config (account / deploy / quota / cost-gate / API scopes) → **immediately update**
the matching section of `infra/<SERVICE>.md`. Identifiers only; credentials never enter these files.
