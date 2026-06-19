---
name: feat
description: Full lifecycle for the "planning phase" of feature development. Triggers when the user says "/feat", "develop feature", "add feature", "implement XX feature", "write a plan", "write DD", "grill me", or "stress test this plan". Workflow: requirement scope analysis → real codebase research (code is ground truth · pull latest · read-only server verification when needed) → grill/clarification gate (walk the design tree branch-by-branch, escalate only genuine ambiguities code can't answer) → collaborative DD plan authoring → 1–3 review agents based on risk level → main flow handles review findings → confirmation gate → hand off to autopilot for development. Solves four high-frequency problems: "forgot to create a branch/worktree", "assumed code behavior from training data", "silently picked one of several viable options without aligning with the human", and "coded before plan was reviewed and confirmed".
version: 2.1.0
---

# /feat — Feature Development Planning Phase (Research → Plan → Review → Confirm)

> **feat owns the first half (producing a researched, reviewed, and confirmed DD); autopilot owns the second half (batch development per DD + code review + delivery).**

Core belief: **Code is ground truth.** Every plan conclusion must be grounded in "actually-read real code / locally-pulled latest repo / read-only-verified real server data". Conclusions based on training data, generic framework assumptions, or guesswork are **prohibited**.

---

## Scope and Boundaries

| Phase | Owner | Artifact |
|-------|-------|----------|
| Requirement scope analysis → code research → grill/clarification → DD plan → plan review → confirmation | **feat (this skill)** | Reviewed and confirmed DD (inside requirement subfolder) |
| Batch development → code review → fixes → archiving + acceptance | **autopilot** | Code + acceptance documents |

feat ends = DD confirmed by a human; autopilot naturally follows.

---

## Phase 0: Pre-flight Checks

### 0.1 Development Environment (worktree default)

Default to worktree-isolated development (no need to ask the user every time unless they haven't specified). Exceptions: explicitly asked for direct main branch / single-file low-risk / pure documentation.

```bash
git branch --show-current
```

- On main branch and doing real development → use `/worktree-dev` (pull new branch from main + create worktree + sync env)
- Already in a feature worktree → record branch name + worktree absolute path, lock cwd throughout (no `cd` drift)

### 0.2 Locate Requirement Subfolder

Determine requirement ID and subfolder `docs/{type}/{ID}/` (new feature / enhancement / fix).
Small features (≤ 2 files, pure additive/copy) may skip the DD and go directly to the confirmation gate, but the rationale must be stated.

### 0.3 Lessons Learned Lookup

Read `docs/lessons/README.md`, match sections to the task's key terms and output a summary of key pitfalls (highlight the most frequent error types in the project). **Non-blocking — continue immediately.**

---

## Phase 1: Requirement Scope Analysis

Break the requirement into a researchable scope list. **Define what to investigate before investigating**:

```
🔍 Requirement Scope Analysis
Requirement: {one sentence}
Modules in this repo: {strategies/freqai/user_data/config — list specific path guesses}
Server/runtime data: {does the plan require verifying DB/deploy config/production state/logs}
Third-party libraries: {is a library being introduced or relied upon for a specific capability}
Risk level: {small / medium / large} (determines number of review agents in Phase 4)
Unknowns: {key questions that require research to answer, listed one by one}
```

Risk level determination (drives review scale):

| Level | Signals |
|-------|---------|
| Small | ≤ 2 files, pure additive/copy, single module |
| Medium | Single-module feature, 3–5 files, has business logic, depends on existing interfaces |
| Large | Architectural decision / new global state / funds·exchange·auth / new dependency selection / cross-module strategy interaction |

---

## Phase 2: Real Codebase Research (Non-Negotiable)

**Skipping this phase and writing the plan directly is a violation.**

### 2.1 Pull Latest Code

```bash
git checkout main && git pull --ff-only
```

> If `pull --ff-only` fails (local has diverged) → **do not reset/merge**; tell the user to handle it themselves.

### 2.2 Read Real Code (Local First, No Assumptions)

| Target | Primary entry point |
|--------|---------------------|
| Strategy logic | Read the actual strategy file(s): class structure, `populate_indicators`, `populate_buy/sell_trend`, custom stoploss, ROI table |
| Interface contracts | Read hyperopt spaces, FreqAI model configs, config schema — confirm actual field names and types, do not guess |
| Current state of this repo | grep real call sites / class definitions / helper functions — confirm existing implementation, do not assume |

Red lines:
- ❌ Assume this project's own code behavior from training data / generic freqtrade knowledge (project-specific strategy code is not in the training set)
- ❌ Use remote web scraping as a substitute for reading code locally (local is faster, greppable, and captures unpushed local branches)
- ✅ If docs conflict with source / docs are marked TBD / pure product decisions → only ask the user after reading both sides

### 2.3 Read-Only Server Verification (when runtime truth is needed)

When the plan depends on **real runtime state** (DB rows, live deploy config, actual exchange API responses, logs, live bot state) that cannot be determined from code, SSH read-only verification is permitted. All servers are registered in `~/.ssh/SERVERS.md`. **Always use aliases — `-i <absolute-path>` is prohibited**:

```bash
ssh {SERVER_ALIAS}     # alias + purpose defined in ~/.ssh/SERVERS.md
```

Read-only verification examples: inspect the trade DB, check deploy config, curl an exchange endpoint for the real response, tail freqtrade logs for real errors.

Red lines:
- ⛔ **Read-only only** — prohibited: write to DB / change config / restart the bot / deploy. Anything involving writes → stop and hand to user
- ⛔ Private key content / credentials / passphrases / API secrets must never be printed to output
- ⛔ Uncertain whether an operation is read-only → ask the user first

### 2.4 Third-Party Library / Interface Capability Verification

- Claiming a library "supports/does not support" a capability → check official docs (e.g., context7) or read installed package source first; training data inference is prohibited
- Introducing a new dependency → first output a top-N comparison table (stars/downloads/last commit/official demo) for user confirmation before installing
- Uncertain about an API path/ownership → `curl` to test the real path + HTTP status code; include the result in the DD

---

## Phase 3: Collaborative Plan Authoring (Grill → Write the DD)

### 3.1 Grill / Clarification Gate (human-in-the-loop)

After research lands and **before** drafting the DD, walk down each branch of the design tree and grill the user on the genuine ambiguities one-by-one until shared understanding, then fold the conclusions into the DD. Purpose: eliminate "writing a plan on assumptions" and "silently picking one of several viable options without aligning with the human".

Trigger:

| Signal | Grill scope |
|--------|-------------|
| Risk **small** and no ambiguity (pure additive/copy) | Skip → go to 3.2 |
| Risk **medium**, or research surfaced ≥1 unknown / multi-option branch that affects plan direction | **Required** — focus on 2–3 key decision groups |
| Risk **large** (exchange contract / funds·auth / architecture / new dependency) | **Required** — walk the full design tree |
| User says "grill me" / "stress test this plan" (can trigger standalone on an existing DD/plan) | Enter this step and grill the target branch-by-branch |

Grill ground rules (inherits Phase 2 "code is ground truth"):

- ⛔ **Questions answerable from code / research / read-only server verification must NOT be asked to the user** — go back to Phase 2 and read code / grep / curl. Only escalate what code genuinely can't answer.
- ✅ Only ask these genuine ambiguities: **product trade-offs** (which behavior/semantics), **priority & scope boundary** (how far this iteration goes), **expected contract of external dependencies** (exchange/data-provider agreements not findable in code), **preference on irreversible decisions** (when the chosen path is hard to roll back).
- 🌲 **Walk the design tree**: one branch at a time; resolve dependent decisions in dependency order (upstream before the downstream it affects). **Focus on one related group per round** — do not dump 20 questions at once.
- 🔁 An answer that spawns new branches → keep drilling until that branch converges; an answer that needs code verification → go back to Phase 2 to confirm, then continue.
- 📝 Record each conclusion immediately as the basis for the DD's **§3 design decisions / §5 decision matrix / ADR** (mark it "aligned with the user", not "AI-chosen").

After the grill converges, proceed to 3.2. **If the grill surfaces a contradiction between the requirement premise and the real code** (interface doesn't exist / architecture conflict / technically infeasible) → go to Exception Handling: stop writing the DD and report with evidence.

### 3.2 Write the DD

Organize into a DD document, placed in the requirement subfolder `docs/{type}/{ID}/{DD|ENH|BUG}.md` (main filename follows `{type}`) + `INDEX.md`. Must include:

- **§1 Background and Scope**: what problem is being solved, which files/modules/servers are involved
- **§2 Research**: **evidence** from this phase — which real code was read (with path + line numbers), branch commit that was pulled, server verification results, curl HTTP codes, library capability verification
- **§3 Plan Design**: components/data flow/key decisions (including alternatives considered + rationale for rejection); multiple viable options with real trade-offs and hard-to-reverse consequences → extract as an ADR
- **§4 Implementation Plan**: broken into Batches (each ≤ 5 files), ready for autopilot to execute directly
- **§5 Decision Matrix**: problem/solution matrix with `[severity / trigger scenario / impact scope / ROI]` 4-column format

> If multiple viable options exist and impact spans more than a single file → **list them explicitly for the human to choose** (this is exactly what the 3.1 grill is meant to surface); do not silently pick one.

---

## Phase 4: 1–3 Review Agents Based on Risk Level (Plan Review)

**After the plan is drafted, before the confirmation gate**, spawn independent subagents to review **the plan itself** (not the code), based on the risk level from Phase 1. The plan-writing context cannot self-review.

| Level | Agent count | Composition (plan review perspective) |
|-------|------------|--------------------------------------|
| Small | **0** | Skip plan review, go directly to confirmation gate |
| Medium | **1** | `oh-my-claudecode:critic` (plan flaws/edge cases/feasibility) |
| Large | **2–3** | `oh-my-claudecode:critic` + `oh-my-claudecode:architect` (architecture/reversibility/cross-module impact) + domain third: `oh-my-claudecode:security-reviewer` (funds/exchange auth) or `oh-my-claudecode:document-specialist` (SDK/library correctness) |

Delegate in parallel (multiple Agent calls in one message). Each agent prompt **must explicitly inject** (subagents do not inherit context):

1. DD absolute path + requirement scope summary + key research evidence points
2. Project key conventions + relevant rules (security/exchange-API as applicable)
3. Review focus: **is the plan grounded in real code** (any assumptions?), are edge cases/exceptions covered, are there better/more reversible options, is the batch breakdown sensible, were library capabilities verified against real docs
4. Output to the requirement subfolder absolute path `reviews/REV-plan-v1-{A|B|C}-{agent}.md` (orthogonal naming to autopilot's `REV-code-v1-*` — same directory, no name collision; second review pass creates `v2`, does not overwrite v1); final message only reports conclusion summary + report path (no full text — prevents context truncation from swallowing the report)

---

## Phase 5: Main Flow Handles Review Findings → Refine DD → Confirmation Gate

### 5.1 Process Findings

Main flow reads all review reports, deduplicates, and auto-handles:
- **Accept**: plan hard defects/gaps/better alternatives → update the DD directly (add research, revise design, adjust batch breakdown)
- **Dispute**: if the review suggestion itself is questionable/unclear → verify first (read code/ask) before deciding; do not blindly follow
- **Defer**: low-ROI plan-level optimizations → note in the DD, do not block

Append a "Plan Review Resolution Record" to the bottom of the DD.

### 5.2 Confirmation Gate ⛔

```
⏸️  Plan Confirmation Gate
DD: docs/{type}/{ID}/{DD|ENH|BUG}.md
Research evidence: {N} real code references / pulled commits / server verifications / curls
Plan review: {K} agents ({verdict}) → resolved
Implementation plan: {M} Batches

This plan requires your confirmation before coding begins. Reply "confirm"/"OK"/"start" to proceed to autopilot, or provide revision feedback.
⛔ Writing any business code before receiving confirmation is prohibited.
```

- Explicit confirmation → proceed to Phase 6; revision feedback → return to Phase 3/5 to adjust and re-gate; ambiguous/silent → request explicit confirmation again

---

## Phase 6: Hand Off to Autopilot

After confirmation, hand off to `autopilot` (DD is in the requirement subfolder with §4 implementation plan): batch development (with appropriate tests per batch) → 1–3 code review agents → handle findings → archive acceptance.

---

## Exception Handling

| Scenario | Action |
|----------|--------|
| User says "quick fix XX" | ≤ 2 files low-risk → simplify (skip DD + skip plan review); otherwise run full flow |
| `pull --ff-only` fails | Do not reset/merge; tell the user to handle it |
| Phase 2 research contradicts requirement premise (interface doesn't exist / architecture conflict / technically infeasible) | **Stop writing the DD** — report to user with real code evidence and wait for requirement adjustment (code is ground truth — ground truth can also veto requirements) |
| Need to write to server/deploy | Stop; operations outside the read-only boundary are handed to the user |
| Docs conflict with code | Read both sides before asking the user which is authoritative |
| A grill question is answerable from code | Do not ask the user — go back to Phase 2 and read code / grep / curl |
| Grill surfaces requirement premise contradicting real code | Stop writing the DD; report with evidence and wait for requirement adjustment (code is ground truth — it can veto requirements) |
| Plan review determines a redo is needed | Pause, report review conclusions, suggest redesign |
| User changes requirements mid-flow | Return to Phase 1 to re-analyze scope |

---

## Safety Red Lines

1. **Code is ground truth** — conclusions must be backed by real code/data; training data assumptions are prohibited
2. **Pull latest before researching** — check out main and pull before writing a plan; writing without pulling is a violation
3. **Server is read-only** — prohibited: write to DB / change config / deploy / restart bot; private key credentials and API secrets must not be printed
4. **Grill only asks what code can't answer** — anything derivable from code / research / read-only server verification must not be asked to the user; only escalate product trade-offs / scope / external contracts / irreversible-decision preferences
5. **Plan review uses independent subagents** — main conversation self-review is prohibited
6. **No coding before confirmation gate** — only enter autopilot after receiving explicit confirmation
7. **Let humans choose among multiple viable options** — when impact spans more than a single file and there are real trade-offs, list options explicitly (surfaced in 3.1 grill, recorded in 3.2 DD)

---

> v2.1 folds the former standalone `grill-me` skill's relentless-interview method into Phase 3.1 (the standalone `grill-me/` remains in this library for non-feat use).
