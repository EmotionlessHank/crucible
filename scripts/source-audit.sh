#!/usr/bin/env bash
# source-audit.sh — first-party source check for recommending/selecting a GitHub project.
# Usage: source-audit.sh owner/repo
# Pulls first-party data via gh api (archived/pushed_at/stars/author followers/contributors/
# commit span) and flags ⚠️ star-inflation suspicion (new-account+new-repo, low followers +
# high star rate, single contributor, commits crammed into a few days).

set -euo pipefail

# ---- thresholds (customizable) ----
FOLLOWERS_LOW="${FOLLOWERS_LOW:-50}"                   # author followers below this = low reach
STARS_PER_DAY_HIGH="${STARS_PER_DAY_HIGH:-30}"        # stars/day above this + low followers = suspicious
ACCOUNT_REPO_GAP_DAYS="${ACCOUNT_REPO_GAP_DAYS:-14}"  # account-created ≈ repo-created within this = suspicious

# ---- preflight ----
command -v gh >/dev/null 2>&1 || { echo "✗ needs gh CLI: brew install gh && gh auth login" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "✗ needs jq: brew install jq" >&2; exit 1; }
[ $# -ge 1 ] || { echo "usage: $0 owner/repo" >&2; exit 1; }

REPO="$1"; OWNER="${REPO%%/*}"; NAME="${REPO##*/}"
[ "$OWNER" != "$REPO" ] && [ -n "$NAME" ] || { echo "✗ expected owner/repo" >&2; exit 1; }

to_epoch() { # ISO8601 -> epoch, macOS/BSD + GNU
  if date -j >/dev/null 2>&1; then date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" "+%s" 2>/dev/null
  else date -u -d "$1" "+%s" 2>/dev/null; fi
}
NOW="$(date -u +%s)"
days_since() { [ -z "$1" ] && { echo "?"; return; }; echo $(( (NOW - $1) / 86400 )); }

echo "════════ first-party source check: $REPO ════════"
REPO_JSON="$(gh api "repos/$REPO" 2>/dev/null)" || { echo "✗ cannot fetch repos/$REPO (missing/private/no-auth)" >&2; exit 1; }

ARCHIVED="$(jq -r '.archived' <<<"$REPO_JSON")"
PUSHED_AT="$(jq -r '.pushed_at' <<<"$REPO_JSON")"
REPO_CREATED="$(jq -r '.created_at' <<<"$REPO_JSON")"
STARS="$(jq -r '.stargazers_count' <<<"$REPO_JSON")"
FORKS="$(jq -r '.forks_count' <<<"$REPO_JSON")"
LICENSE="$(jq -r '.license.spdx_id // "none"' <<<"$REPO_JSON")"
DESC="$(jq -r '.description // ""' <<<"$REPO_JSON")"

REPO_CREATED_EPOCH="$(to_epoch "$REPO_CREATED" || true)"
REPO_AGE_DAYS="$(days_since "$REPO_CREATED_EPOCH")"
PUSHED_DAYS_AGO="$(days_since "$(to_epoch "$PUSHED_AT" || true)")"

echo; echo "[repo]"
if [ "$ARCHIVED" = "true" ]; then echo "  ⚠️ archived = true — UNMAINTAINED. Must tell the user."
else echo "  archived = false"; fi
echo "  pushed_at = $PUSHED_AT ($PUSHED_DAYS_AGO days ago)"
echo "  created   = $REPO_CREATED (age $REPO_AGE_DAYS days)"
echo "  stars=$STARS forks=$FORKS license=$LICENSE"
[ -n "$DESC" ] && echo "  desc = $DESC"

USER_JSON="$(gh api "users/$OWNER" 2>/dev/null)" || USER_JSON=""
FOLLOWERS="?"; USER_CREATED=""; PUBLIC_REPOS="?"
if [ -n "$USER_JSON" ]; then
  FOLLOWERS="$(jq -r '.followers' <<<"$USER_JSON")"
  USER_CREATED="$(jq -r '.created_at' <<<"$USER_JSON")"
  PUBLIC_REPOS="$(jq -r '.public_repos' <<<"$USER_JSON")"
fi
USER_CREATED_EPOCH="$(to_epoch "$USER_CREATED" || true)"
echo; echo "[author]"; echo "  followers=$FOLLOWERS public_repos=$PUBLIC_REPOS created=${USER_CREATED:-?}"

CONTRIBUTORS="$(gh api "repos/$REPO/contributors?per_page=100" 2>/dev/null | jq -r 'length' 2>/dev/null || echo "?")"
echo; echo "[contributors] count=$CONTRIBUTORS"

COMMITS_JSON="$(gh api "repos/$REPO/commits?per_page=100" 2>/dev/null || echo "[]")"
CF="$(jq -r '[.[].commit.committer.date] | min // ""' <<<"$COMMITS_JSON" 2>/dev/null || echo "")"
CL="$(jq -r '[.[].commit.committer.date] | max // ""' <<<"$COMMITS_JSON" 2>/dev/null || echo "")"
COMMIT_COUNT="$(jq -r 'length' <<<"$COMMITS_JSON" 2>/dev/null || echo "?")"
SPAN_DAYS="?"
if [ -n "$CF" ] && [ -n "$CL" ]; then
  A="$(to_epoch "$CF" || true)"; B="$(to_epoch "$CL" || true)"
  [ -n "$A" ] && [ -n "$B" ] && SPAN_DAYS=$(( (B - A) / 86400 ))
fi
echo; echo "[recent commits] count=$COMMIT_COUNT span=${SPAN_DAYS}d ($CF -> $CL)"

echo; echo "──────── inflation/bubble check ────────"
SUSPICION=0
if [ -n "$USER_CREATED_EPOCH" ] && [ -n "$REPO_CREATED_EPOCH" ]; then
  ABS_GAP=$(( (REPO_CREATED_EPOCH - USER_CREATED_EPOCH) / 86400 )); [ "$ABS_GAP" -lt 0 ] && ABS_GAP=$(( -ABS_GAP ))
  if [ "$ABS_GAP" -le "$ACCOUNT_REPO_GAP_DAYS" ]; then
    echo "  ⚠️ account-created ≈ repo-created (gap ${ABS_GAP}d ≤ ${ACCOUNT_REPO_GAP_DAYS}) → new account, new repo"; SUSPICION=$((SUSPICION+1)); fi
fi
if [ "$FOLLOWERS" != "?" ] && [ "$REPO_AGE_DAYS" != "?" ] && [ "$REPO_AGE_DAYS" -gt 0 ]; then
  SPD=$(( STARS / REPO_AGE_DAYS )); echo "  stars/day ≈ $SPD ($STARS / ${REPO_AGE_DAYS}d), followers=$FOLLOWERS"
  if [ "$SPD" -ge "$STARS_PER_DAY_HIGH" ] && [ "$FOLLOWERS" -lt "$FOLLOWERS_LOW" ]; then
    echo "  ⚠️ high star rate (≥${STARS_PER_DAY_HIGH}/d) + low followers (<${FOLLOWERS_LOW}) → disproportionate to real reach"; SUSPICION=$((SUSPICION+1)); fi
fi
[ "$CONTRIBUTORS" != "?" ] && [ "$CONTRIBUTORS" -le 1 ] && { echo "  ⚠️ single contributor"; SUSPICION=$((SUSPICION+1)); }
[ "$SPAN_DAYS" != "?" ] && [ "$SPAN_DAYS" -le 7 ] && [ "$COMMIT_COUNT" != "?" ] && [ "$COMMIT_COUNT" -gt 1 ] && { echo "  ⚠️ commits crammed into ${SPAN_DAYS}d"; SUSPICION=$((SUSPICION+1)); }

echo
[ "$ARCHIVED" = "true" ] && echo "verdict: ⚠️ archived (unmaintained) — high stars do not mean usable."
if [ "$SUSPICION" -ge 2 ]; then echo "verdict: ⚠️ inflation/coordinated-promo suspected ($SUSPICION hits) → pollution warning + heavy downweight. High stars ≠ trustworthy."
elif [ "$SUSPICION" -eq 1 ]; then echo "verdict: ⚠ one suspicious signal → check the issue tracker for real negatives."
else echo "verdict: no inflation signals; still check archived/activity/issues before concluding."; fi
echo "note: aggregator/directory sites are README mirrors, not independent sources — weight does not stack."
