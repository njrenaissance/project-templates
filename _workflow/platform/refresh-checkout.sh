#!/usr/bin/env bash
#
# refresh-checkout.sh — bring a cached checkout's main up to origin/main, or fail.
#
# Usage: refresh-checkout.sh [<checkout-dir>]     (default: current directory)
#
# Exits 0 when main equals origin/main afterwards. Exits 1 with a "blocked:"
# message on stderr when it cannot fast-forward (dirty tree, local commits,
# diverged history, fetch failure). Never resets, force-pushes, or discards work.

set -euo pipefail

die() { printf 'refresh-checkout: blocked: %s\n' "$*" >&2; exit 1; }

DIR="${1:-.}"
cd "$DIR" 2>/dev/null || die "no such directory: $DIR"
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git checkout: $DIR"

git fetch -q origin || die "git fetch origin failed"
[[ -z "$(git status --porcelain)" ]] || die "working tree has uncommitted changes"
git checkout -q main || die "cannot check out main"

OLD="$(git rev-parse main)"
git merge --ff-only -q origin/main || die "main cannot fast-forward to origin/main (local commits or diverged history)"
NEW="$(git rev-parse main)"
[[ "$NEW" == "$(git rev-parse origin/main)" ]] || die "main does not match origin/main after merge"

if [[ "$OLD" == "$NEW" ]]; then
  echo "refresh-checkout: main already current at $NEW"
else
  echo "refresh-checkout: main fast-forwarded $OLD -> $NEW"
fi
