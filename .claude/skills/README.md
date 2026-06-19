# Skills (workspace)

Project-local Claude Code skills for crucible. The three workflow skills are adapted from
[amazing-dev-skills](https://github.com/EmotionlessHank) to this project's stack
(Python / freqtrade / ruff / pytest / single repo / no UI; review agents mapped to OMC agents).

## Dev workflow pipeline (adapted)

| Skill | Trigger | Role |
|---|---|---|
| `feat` | "/feat", "develop feature", "write DD", "grill me" | Planning: scope → real-code research → grill gate → DD → 1–3 plan-review agents → confirmation gate → hand off to autopilot |
| `worktree-dev` | "/worktree-dev", "isolated dev", "open a worktree" | Isolation: branch from main → worktree at `.worktrees/<name>` → symlink env (`.env`, `config/config.live.json`) → cwd lock |
| `autopilot` | plan confirmed ("confirm"/"start"), "/autopilot" | Execution: batch dev (≤5 files, tests per batch) → 1–3 parallel code-review agents → auto-triage fixes → archive CHANGES/TEST_PLAN/ACCEPTANCE → dev summary → acceptance |

Flow: **feat → worktree-dev → autopilot**. Requirement artifacts live in `docs/{designs,enh,bug}/{ID}/`.

## Utility skills (generic, as-is)

| Skill | Role |
|---|---|
| `grill-me` | Relentless decision-tree interview to stress-test a plan (also embedded in feat Phase 3.1) |
| `patch-audit` | Detect patch-on-patch commit history and refactor into a clean implementation |
| `partial-commit` | Commit only this session's changes, ignoring parallel-tab edits |

## Project adaptation values (for re-adaptation reference)

`MAIN_BRANCH=main` · `WORKTREE_BASE=.worktrees` (gitignored) · `DOCS_ROOT=docs` ·
`INSTALL=pip install -r requirements.txt` · `TYPECHECK=ruff check .` · `LINT=ruff format --check .` ·
`TEST=pytest -q` · `BUILD=python -m compileall -q .` · `MAX_FILES_PER_BATCH=5` ·
`LESSONS=docs/lessons/README.md` · review agents → `oh-my-claudecode:{code-reviewer,critic,architect,security-reviewer,test-engineer,document-specialist}`.

## Not loaded (and why)
finance-* (personal household budgeting, not trading) · design/UI/web/system/personal skills (N/A) ·
sentry (defer to Phase 2) · parallel-worktree (add when parallelizing) · project-rules-initialization (rules already set up).
