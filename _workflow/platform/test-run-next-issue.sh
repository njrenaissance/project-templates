#!/usr/bin/env bash
#
# Unit tests for run-next-issue.sh. gh and ant are stubbed as shell functions,
# so nothing here touches GitHub or Anthropic. Run from anywhere:
#   _workflow/platform/test-run-next-issue.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=run-next-issue.sh
source "$HERE/run-next-issue.sh"

REPO="owner/repo"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CALLS="$TMP/calls"
pass=0
fail=0

# Fixtures, reset per case.
FIX_ISSUES="[]"
FIX_PRS="[]"
FIX_LOCKS=""
FIX_COMMENTS=""
CLOSED=""
LABELS=""
FIX_STATUS="idle"
FIX_RETRIEVE_FAIL=""

gh() {
  case "$*" in
    "issue list"*) printf '%s' "$FIX_ISSUES" ;;
    "pr list"*) printf '%s' "$FIX_PRS" ;;
    "search issues"*) printf '%s' "$FIX_LOCKS" ;;
    "issue view "*"--json state"*)
      if [[ " $CLOSED " == *" $3 "* ]]; then echo CLOSED; else echo OPEN; fi ;;
    "issue view "*"--json labels"*) printf '%s\n' $LABELS ;;
    "issue view "*"--json comments"*) printf '%s\n' "$FIX_COMMENTS" ;;
    "issue edit "*|"issue comment "*) echo "$*" >> "$CALLS" ;;
    *) ;;
  esac
}

ant() {
  case "$*" in
    *"--transform status"*)
      [[ -z "$FIX_RETRIEVE_FAIL" ]] || return 1
      printf '%s' "$FIX_STATUS" ;;
  esac
}

assert_eq() { # name expected actual
  if [[ "$2" == "$3" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $1: expected [$2] got [$3]"
  fi
}

calls_matching() { # pattern -> count of recorded gh write calls matching it
  grep -c -- "$1" "$CALLS" 2>/dev/null || true
}

# parse_deps: prints the dependency numbers, or ERR when the section is rejected.
parse_case() { # name body expected
  local out rc=0
  out="$(parse_deps "$2")" || rc=$?
  if (( rc != 0 )); then out="ERR"; fi
  assert_eq "parse_deps: $1" "$3" "$out"
}

parse_case "None" "$(printf '## Depends on\nNone')" ""
parse_case "none lowercase" "$(printf '## Depends on\nnone')" ""
parse_case "bullet list" "$(printf '## Depends on\n- #3\n- #5')" "$(printf '3\n5')"
parse_case "comma list" "$(printf '## Depends on\n#3, #5')" "$(printf '3\n5')"
parse_case "stops at next heading" "$(printf '## Depends on\n#3\n## Notes\nNone')" "3"
parse_case "no section" "$(printf 'Just prose')" "ERR"
parse_case "empty section" "$(printf '## Depends on\n')" "ERR"
parse_case "prose in section" "$(printf '## Depends on\nsee the auth issue')" "ERR"
parse_case "malformed number" "$(printf '## Depends on\n#3a')" "ERR"

# select_issue: skips held and locked issues, open dependencies, malformed
# sections and open PRs. Otherwise urgent first, then bugs, then lowest number.
FIX_ISSUES='[
 {"number":7,"body":"## Depends on\nNone","labels":[]},
 {"number":1,"body":"## Depends on\nNone","labels":[{"name":"needs-human"}]},
 {"number":2,"body":"## Depends on\n#10","labels":[]},
 {"number":3,"body":"no dependency section","labels":[]},
 {"number":4,"body":"## Depends on\nNone","labels":[]},
 {"number":5,"body":"## Depends on\nNone","labels":[]},
 {"number":6,"body":"## Depends on\n- #8\n","labels":[]},
 {"number":11,"body":"## Depends on\nNone","labels":[{"name":"agent-running"}]}
]'
FIX_PRS='[
 {"number":40,"headRefName":"issue-4-fix","body":"no link"},
 {"number":41,"headRefName":"feature","body":"Fixes #5"}
]'
CLOSED="8"
select_issue >/dev/null 2>&1
assert_eq "select: skips held, locked, open dep, malformed, open PRs; picks lowest eligible" "6" "$SELECTED"

CLOSED="8 10"
select_issue >/dev/null 2>&1
assert_eq "select: a closed dependency makes an issue eligible" "2" "$SELECTED"

FIX_ISSUES='[
 {"number":1,"body":"## Depends on\nNone","labels":[{"name":"needs-human"}]},
 {"number":3,"body":"no dependency section","labels":[]}
]'
FIX_PRS="[]"
select_issue >/dev/null 2>&1
assert_eq "select: nothing eligible gives an empty selection" "" "$SELECTED"

# Priority: urgent+bug, then urgent, then bug, then the rest by number.
FIX_ISSUES='[
 {"number":2,"body":"## Depends on\nNone","labels":[{"name":"enhancement"}]},
 {"number":4,"body":"## Depends on\nNone","labels":[{"name":"bug"}]},
 {"number":7,"body":"## Depends on\nNone","labels":[{"name":"urgent"}]},
 {"number":9,"body":"## Depends on\nNone","labels":[{"name":"bug"},{"name":"urgent"}]}
]'
FIX_PRS="[]"
CLOSED=""
select_issue >/dev/null 2>&1
assert_eq "priority: urgent bug first" "9" "$SELECTED"
FIX_ISSUES='[
 {"number":2,"body":"## Depends on\nNone","labels":[{"name":"enhancement"}]},
 {"number":4,"body":"## Depends on\nNone","labels":[{"name":"bug"}]},
 {"number":7,"body":"## Depends on\nNone","labels":[{"name":"urgent"}]}
]'
select_issue >/dev/null 2>&1
assert_eq "priority: urgent before bug" "7" "$SELECTED"
FIX_ISSUES='[
 {"number":2,"body":"## Depends on\nNone","labels":[{"name":"enhancement"}]},
 {"number":4,"body":"## Depends on\nNone","labels":[{"name":"bug"}]}
]'
select_issue >/dev/null 2>&1
assert_eq "priority: bug before feature, despite higher number" "4" "$SELECTED"

# reconcile: release, hold, or keep the lock, from the PR and session state.
# Every case starts with a fresh call log.
reconcile_case() { # name expected-locked expected-remove expected-add
  : > "$CALLS"
  LOCKED=false
  reconcile >/dev/null 2>&1
  assert_eq "reconcile: $1 locked" "$2" "$LOCKED"
  assert_eq "reconcile: $1 releases lock" "$3" "$(calls_matching '--remove-label agent-running')"
  assert_eq "reconcile: $1 holds" "$4" "$(calls_matching '--add-label needs-human')"
}

SESSION_COMMENT='Inner Loop session sesn_abc123 started by the driver.'

FIX_LOCKS="owner/repo 5"
FIX_PRS='[{"number":9,"headRefName":"issue-5-build","body":""}]'
FIX_COMMENTS="$SESSION_COMMENT"
FIX_STATUS="running"
reconcile_case "open PR releases the lock" "false" "1" "0"

FIX_PRS="[]"
FIX_STATUS="idle"
reconcile_case "idle session with no PR holds the issue" "false" "1" "1"

FIX_STATUS="running"
reconcile_case "running session keeps the lock" "true" "0" "0"

FIX_STATUS="idle"
FIX_RETRIEVE_FAIL=1
reconcile_case "status read failure keeps the lock" "true" "0" "0"
FIX_RETRIEVE_FAIL=""

FIX_COMMENTS=""
reconcile_case "lock with no recorded session holds the issue" "false" "1" "1"

FIX_LOCKS=""
reconcile_case "no lock, nothing to reconcile" "false" "0" "0"

# Dry run reports what it would do and writes nothing.
FIX_LOCKS="owner/repo 5"
FIX_COMMENTS="$SESSION_COMMENT"
FIX_STATUS="idle"
DRY_RUN=true
reconcile_case "dry run makes no writes" "false" "0" "0"
DRY_RUN=false

echo "run-next-issue tests: $pass passed, $fail failed"
(( fail == 0 ))
