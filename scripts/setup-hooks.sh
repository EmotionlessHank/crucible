#!/usr/bin/env bash
# Enable the version-controlled git hooks for this clone. Run once after cloning.
set -euo pipefail
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true
echo "Hooks enabled: core.hooksPath=.githooks"
