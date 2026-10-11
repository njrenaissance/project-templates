#!/usr/bin/env bash
#
# Tests for ../refresh-checkout.sh. Builds a throwaway origin and a "cached"
# clone in a temp dir, then checks each outcome. Run: bash _workflow/platform/test/refresh-checkout.test.sh

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../refresh-checkout.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

# origin with one commit on main, a cached clone of it, and a pusher to advance origin
git init -q -b main "$WORK/origin.git" --bare
git clone -q "$WORK/origin.git" "$WORK/pusher" 2>/dev/null
git -C "$WORK/pusher" checkout -q -b main
echo a > "$WORK/pusher/a.txt"; git -C "$WORK/pusher" add a.txt; git -C "$WORK/pusher" commit -qm a
git -C "$WORK/pusher" push -q origin main

reset_cache() {
  rm -rf "$WORK/cache"
  git clone -q "$WORK/origin.git" "$WORK/cache"
}
advance_origin() {
  echo "$1" > "$WORK/pusher/$1.txt"; git -C "$WORK/pusher" add "$1.txt"
  git -C "$WORK/pusher" commit -qm "$1"; git -C "$WORK/pusher" push -q origin main
}

# 1. already current -> exit 0, reports current
reset_cache
out="$(bash "$SCRIPT" "$WORK/cache")" || fail "current checkout should exit 0"
[[ "$out" == *"already current"* ]] || fail "current checkout should say so: $out"
pass "already current exits 0 and says so"

# 2. behind -> fast-forwards, reports old -> new, matches origin
reset_cache
advance_origin b
old="$(git -C "$WORK/cache" rev-parse main)"
out="$(bash "$SCRIPT" "$WORK/cache")" || fail "behind checkout should fast-forward"
[[ "$out" == *"fast-forwarded $old ->"* ]] || fail "should report old SHA: $out"
[[ "$(git -C "$WORK/cache" rev-parse HEAD)" == "$(git -C "$WORK/origin.git" rev-parse main)" ]] || fail "HEAD should equal origin/main"
pass "behind checkout is fast-forwarded and reports SHAs"

# 3. behind while on another branch -> moves to main and matches origin
reset_cache
advance_origin c
git -C "$WORK/cache" checkout -q -b issue-1-x
bash "$SCRIPT" "$WORK/cache" >/dev/null || fail "should switch to main and fast-forward"
[[ "$(git -C "$WORK/cache" rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "should end on main"
pass "off-main checkout is moved to main and fast-forwarded"

# 4. dirty working tree -> blocked, nothing changed
reset_cache
advance_origin d
echo junk >> "$WORK/cache/a.txt"
before="$(git -C "$WORK/cache" rev-parse HEAD)"
if bash "$SCRIPT" "$WORK/cache" 2>"$WORK/err"; then fail "dirty tree should exit 1"; fi
grep -q "blocked: working tree has uncommitted changes" "$WORK/err" || fail "dirty tree message: $(cat "$WORK/err")"
[[ "$(git -C "$WORK/cache" rev-parse HEAD)" == "$before" ]] || fail "dirty tree must not move HEAD"
pass "dirty tree is blocked and HEAD is untouched"

# 5. local commit on main, diverged from origin -> blocked, nothing discarded
reset_cache
advance_origin e
echo local > "$WORK/cache/local.txt"; git -C "$WORK/cache" add local.txt; git -C "$WORK/cache" commit -qm local
before="$(git -C "$WORK/cache" rev-parse HEAD)"
if bash "$SCRIPT" "$WORK/cache" 2>"$WORK/err"; then fail "diverged checkout should exit 1"; fi
grep -q "blocked: main cannot fast-forward" "$WORK/err" || fail "diverged message: $(cat "$WORK/err")"
[[ "$(git -C "$WORK/cache" rev-parse HEAD)" == "$before" ]] || fail "diverged must not reset local commit"
pass "diverged main is blocked and local commit is kept"

# 6. not a git checkout -> blocked
mkdir "$WORK/notgit"
if bash "$SCRIPT" "$WORK/notgit" 2>"$WORK/err"; then fail "non-git dir should exit 1"; fi
grep -q "not a git checkout" "$WORK/err" || fail "non-git message: $(cat "$WORK/err")"
pass "non-git directory is blocked"

echo "all refresh-checkout tests passed"
