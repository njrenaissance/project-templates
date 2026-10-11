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
CLOSED=""
LABELS=""
FIX_STATUS="idle"
FIX_EVENTS='{"data":[]}'
FIX_RETRIEVE_FAIL=""

gh() {
  case "$*" in
    "issue list"*) printf '%s' "$FIX_ISSUES" ;;
    "pr list"*) printf '%s' "$FIX_PRS" ;;
    "issue view "*"--json state"*)
      if [[ " $CLOSED " == *" $3 "* ]]; then echo CLOSED; else echo OPEN; fi ;;
    "issue view "*"--json labels"*) printf '%s\n' $LABELS ;;
    "issue edit "*) echo "$*" >> "$CALLS" ;;
    *) ;;
  esac
}

ant() {
  case "$*" in
    *"--transform status"*)
      [[ -z "$FIX_RETRIEVE_FAIL" ]] || return 1
      printf '%s' "$FIX_STATUS" ;;
    *"events list"*) printf '%s' "$FIX_EVENTS" ;;
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

# select_issue: lowest-numbered eligible issue, with reasons for each skip.
FIX_ISSUES='[
 {"number":7,"body":"## Depends on\nNone","labels":[]},
 {"number":1,"body":"## Depends on\nNone","labels":[{"name":"needs-human"}]},
 {"number":2,"body":"## Depends on\n#10","labels":[]},
 {"number":3,"body":"no dependency section","labels":[]},
 {"number":4,"body":"## Depends on\nNone","labels":[]},
 {"number":5,"body":"## Depends on\nNone","labels":[]},
 {"number":6,"body":"## Depends on\n- #8\n","labels":[]}
]'
FIX_PRS='[
 {"number":40,"headRefName":"issue-4-fix","body":"no link"},
 {"number":41,"headRefName":"feature","body":"Fixes #5"}
]'
CLOSED="8"
select_issue >/dev/null 2>&1
assert_eq "select: skips label, open dep, malformed, open PRs; picks lowest eligible" "6" "$SELECTED"

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

# Outcome handling: read_outcome then apply_outcome, as main does.
ev() { # status -> result event with that status, as the agent would write it
  jq -cn --arg s "$1" '{data:[{type:"agent.message",content:[{type:"text",
    text:({stage:"inner-loop",repo:"owner/repo",issue:6,status:$s,pr:null,plan_comment:null,problem:"p"}|tostring)}]}]}'
}

outcome_case() { # name expected-status expect-label events labels
  FIX_EVENTS="$4"
  LABELS="$5"
  : > "$CALLS"
  read_outcome 99
  apply_outcome 99 >/dev/null 2>&1
  local edits
  edits="$(grep -c 'issue edit' "$CALLS" || true)"
  assert_eq "outcome: $1 status" "$2" "$STATUS"
  assert_eq "outcome: $1 labelled" "$3" "$edits"
}

outcome_case "done leaves the issue alone" "done" "0" "$(ev done)" ""
outcome_case "escalated is held" "escalated" "1" "$(ev escalated)" ""
outcome_case "awaiting_approval is held" "awaiting_approval" "1" "$(ev awaiting_approval)" ""
outcome_case "blocked is held" "blocked" "1" "$(ev blocked)" ""
outcome_case "no result is blocked and held" "blocked" "1" '{"data":[]}' ""
outcome_case "invalid JSON is blocked and held" "blocked" "1" \
  "$(jq -cn '{data:[{content:[{text:"{\"stage\":\"inner-loop\" \"status\":\"done\"}"}]}]}')" ""
outcome_case "already labelled is not re-labelled" "escalated" "0" "$(ev escalated)" "needs-human"

# Timeout and retrieval failures are blocked, not crashes.
WAIT_TIMEOUT_SECONDS=0
FIX_STATUS="running"
outcome_case "timeout is blocked and held" "blocked" "1" "$(ev done)" ""
WAIT_TIMEOUT_SECONDS=18000
FIX_STATUS="idle"

FIX_RETRIEVE_FAIL=1
outcome_case "status read failure is blocked and held" "blocked" "1" "$(ev done)" ""
FIX_RETRIEVE_FAIL=""

echo "run-next-issue tests: $pass passed, $fail failed"
(( fail == 0 ))
