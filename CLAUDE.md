# crucible — Project Rules

Darwinian strategy-culling machine for crypto swing trading. See `docs/architecture-design.md`
for the full blueprint and `docs/best-practices-research.md` for the sourced research behind it.

## 0. Read before working — lessons map (RAG, mandatory, saves context)

Before any work, load **only** `docs/lessons/README.md` (a lightweight RAG tag map). Match current-task
keywords against the tags:
- **Hit** → read that `L-NNN` (usually 1–3); avoid a gotcha already paid for.
- **No hit** → don't open L files; just proceed.
- **New gotcha** → after fixing, add an `L-NNN` + one map row (incrementing, no reuse, no gaps).

## Language policy (strict)

- **Code, comments, and commit messages: English only.** No Chinese in committed code or commits.
- **README: bilingual (English + 中文) with navigation.**
- **Committed docs (architecture, design, research, code docs): English.**
- **Local-only process notes may be Chinese** — e.g. `.progress/` working notes (gitignored, never uploaded).

## Secret & money safety (red lines)

- **Never commit secrets.** No API keys, secret keys, private keys, `.env`, or `config/config.live.json`.
  Always load credentials from environment variables.
- A pre-commit secret guard lives in `.githooks/pre-commit`. Enable it once per clone:
  `git config core.hooksPath .githooks` (or run `bash scripts/setup-hooks.sh`).
- API keys used for live trading must be **withdrawal-disabled** and **IP-allowlisted** (see architecture §7).

## Engineering conventions

- Python 3.11+. Execution loop on `freqtrade`; validation stats custom (`research/`); experiment tracking via MLflow.
- Keep authoring and review in separate passes; verify before claiming done.
- Data, `mlruns/`, `journal/`, `registry/` are gitignored (regenerable / large / sensitive).

## Selection / research (first-party source audit)

When recommending/selecting any library, framework, or data source, **run the first-party check on the
first answer** — don't wait to be asked to fact-check. Run `bash scripts/source-audit.sh owner/repo`
(or `gh api repos/{o}/{r}` → `archived` / `pushed_at` / stars; `users/{login}` → followers/created).
Star-inflation signals (new-account ≈ new-repo, low followers + high star rate, single contributor,
commits crammed into days) → ⚠️ pollution warning + heavy downweight. High stars ≠ trustworthy.
Aggregator/directory sites are README mirrors, not independent sources.

## Verification (live acceptance smoke)

Static green ≠ live green. Before claiming a live/exec change works, run real-environment checks per
`docs/live-acceptance-smoke.md` (reconnect / duplicate-order / outage / timeout / reconciliation probes).
Self-verify first; deterministic → auto-assert; uncertain → manual checklist, never fake-green.
Caught a bug → distill into an `L-NNN`.

## Infra config (single source of truth)

After changing any service config (account / deploy / quota / cost-gate / API scopes) → immediately update
the matching section of `infra/<SERVICE>.md`. **Identifiers only; credentials never enter these files** (see `infra/README.md`).

## Decision ledger (locked — see architecture-design.md for full context)

- Market: large-liquidity **BTC** first; swing (hours–days); perpetual futures in the live phase.
- Capital: ~1% experimental **satellite** sleeve (core is already DCA'd). Drawdown tolerance −40~−50%.
- Goal: **absolute return** (positive annual + controlled drawdown). 100%+ annual is an *outcome*
  of (validated edge × leverage), **never an admission criterion**.
- **Fitness optimizes survival-then-risk-adjusted (Calmar), not raw return** — the core anti-overfit guard.
- Admission gate: walk-forward / DSR / PBO / parameter-plateau / net-edge / paper-holds. **No return threshold.**
- Phases: P0 build (~1–2 wk) → P1 paper self-iteration (1-month time-box) → P2 real money (auto-deploy + hard guardrails).

## Working notes

- Chinese progress logs go in `.progress/` (gitignored). Keep the repo itself English-only.
