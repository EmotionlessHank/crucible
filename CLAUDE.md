# crucible — Project Rules

Darwinian strategy-culling machine for crypto swing trading. See `docs/architecture-design.md`
for the full blueprint and `docs/best-practices-research.md` for the sourced research behind it.

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
