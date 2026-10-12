#!/usr/bin/env bash
#
# run-issue.sh — work one GitHub issue with the Inner Loop managed agent.
#
# Usage (from the repo root, after `ant apply _workflow/platform`):
#   GITHUB_TOKEN=<fine-grained PAT> SESSION_BUDGET=<cents> _workflow/platform/run-issue.sh <owner/repo> <issue> [--require-plan-approval]
#
# Creates one session: mounts <owner/repo>, attaches the credential vault, and
# sends the kickoff message. Prints the session ID. Requires: ant, jq.
#
# SESSION_BUDGET is the hard spend ceiling for the session, in cents (200 = $2).
# The session stops issuing model requests once it reaches that cost.

set -euo pipefail

VAULT_ID="vlt_011Cdb285v3WU3iywUaK3jSG"
LOCK="${CLAUDE_LOCK:-claude-lock.json}"

die() { printf 'run-issue: %s\n' "$*" >&2; exit 1; }

REPO="${1:-}"; ISSUE="${2:-}"; REQUIRE="false"
[[ -n "$REPO" && -n "$ISSUE" ]] || die "usage: run-issue.sh <owner/repo> <issue> [--require-plan-approval]"
[[ "$REPO" == */* ]] || die "repo must be <owner>/<name>, got: $REPO"
[[ "$ISSUE" =~ ^[0-9]+$ ]] || die "issue must be a number, got: $ISSUE"
[[ "${3:-}" == "--require-plan-approval" ]] && REQUIRE="true"

: "${GITHUB_TOKEN:?set GITHUB_TOKEN to a fine-grained PAT for $REPO}"
: "${SESSION_BUDGET:?set SESSION_BUDGET to a spend ceiling in cents, e.g. 200 for two dollars}"
[[ "$SESSION_BUDGET" =~ ^[1-9][0-9]*$ ]] || die "SESSION_BUDGET must be a whole number of cents, got: $SESSION_BUDGET"
for bin in ant jq; do command -v "$bin" >/dev/null 2>&1 || die "$bin not found on PATH"; done
[[ -f "$LOCK" ]] || die "$LOCK not found; run from the repo root after \`ant apply _workflow/platform\`"

AGENT_ID="$(jq -r '.resources | to_entries[] | select(.key | endswith("/inner-loop.yml")) | .value.id' "$LOCK" | head -n1)"
ENVIRONMENT_ID="$(jq -r '.resources | to_entries[] | select(.value.kind=="environment") | .value.id' "$LOCK" | head -n1)"
[[ -n "$AGENT_ID" && -n "$ENVIRONMENT_ID" ]] || die "no agent/environment IDs in $LOCK"

ant beta:sessions create --transform id --raw-output <<YAML
agent: $AGENT_ID
environment_id: $ENVIRONMENT_ID
budget:
  type: limit
  max_list_cost:
    amount: "$SESSION_BUDGET"
    currency: USD
vault_ids:
  - $VAULT_ID
resources:
  - type: github_repository
    url: https://github.com/$REPO
    authorization_token: $GITHUB_TOKEN
initial_events:
  - type: user.message
    content:
      - type: text
        text: |
          repo: $REPO
          issue: $ISSUE
          require_plan_approval: $REQUIRE
YAML
