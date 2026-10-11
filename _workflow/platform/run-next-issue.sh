#!/usr/bin/env bash
#
# run-next-issue.sh — pick the next eligible issue and run it with the Inner Loop.
#
# Selection rule and outcome handling: _workflow/platform/driver-spec.md.
# Runs from the repo root, as the "Run next issue" GitHub Action does. Requires:
# gh (authenticated via GH_TOKEN), ant, jq, and claude-lock.json at the repo root.
#
# Usage:
#   GH_TOKEN=<token> RUN_TOKEN=<repo PAT> ANTHROPIC_API_KEY=<key> \
#     _workflow/platform/run-next-issue.sh <owner/repo> [--dry-run]
#
# Env:
#   DAILY_RUN_CAP            max live launches in any rolling 24h (default 3)
#   WAIT_TIMEOUT_SECONDS     how long to wait for the session to finish (default 18000)
#   REQUIRE_PLAN_APPROVAL    launch with --require-plan-approval (default true)
#
# The cap counts runs whose run-name ends in "(live)"; dry runs carry "(dry run)".

set -euo pipefail

DAILY_RUN_CAP="${DAILY_RUN_CAP:-3}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-18000}"
POLL_SECONDS="${POLL_SECONDS:-30}"
REQUIRE_PLAN_APPROVAL="${REQUIRE_PLAN_APPROVAL:-true}"
LABEL="needs-human"
WORKFLOW_FILE="run-next-issue.yml"
LIVE_TAG="(live)"

log() { printf 'run-next-issue: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# Print the issue numbers listed under "## Depends on". Print nothing for "None".
# Returns 1 if the section is missing, empty, or contains anything other than
# "None" or "#<number>" tokens. Callers treat 1 as "cannot select this issue".
parse_deps() {
  local body="$1" section cleaned tok
  grep -q '^## Depends on[[:space:]]*$' <<< "$body" || return 1
  section="$(awk '
    /^## Depends on[[:space:]]*$/ { on = 1; next }
    /^## /                        { on = 0 }
    on                            { print }' <<< "$body")"
  cleaned="$(sed -E 's/^[[:space:]]*[-*][[:space:]]*//' <<< "$section" | tr -s ' \t,' '\n' | sed '/^$/d')"
  [[ -n "$cleaned" ]] || return 1
  while IFS= read -r tok; do
    case "$tok" in
      None|none) ;;
      \#[0-9]*) [[ "$tok" =~ ^\#[0-9]+$ ]] || return 1; printf '%s\n' "${tok#\#}" ;;
      *) return 1 ;;
    esac
  done <<< "$cleaned"
}

# Count live launches of this workflow in the last 24h, excluding the current run.
recent_launches() {
  local since
  since="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
  gh run list -R "$REPO" --workflow "$WORKFLOW_FILE" --limit 100 --json createdAt,databaseId,displayTitle \
    -q "[.[] | select(.createdAt >= \"$since\" and (.displayTitle | endswith(\"$LIVE_TAG\"))
      and (.databaseId | tostring) != \"${GITHUB_RUN_ID:-0}\")] | length"
}

# Set SELECTED to the lowest-numbered eligible issue. Print a reason for every skip.
select_issue() {
  local open_issues open_prs issue n body deps d state has_pr blocked
  open_issues="$(gh issue list -R "$REPO" --state open --limit 500 --json number,body,labels)"
  open_prs="$(gh pr list -R "$REPO" --state open --limit 500 --json number,headRefName,body)"
  SELECTED=""

  while IFS= read -r issue; do
    n="$(jq -r '.number' <<< "$issue")"
    body="$(jq -r '.body // ""' <<< "$issue")"

    if jq -e --arg l "$LABEL" 'any(.labels[]?; .name == $l)' <<< "$issue" >/dev/null; then
      log "#$n skipped: has $LABEL label"; continue
    fi

    has_pr="$(jq -r --arg n "$n" '[.[] | select((.headRefName | startswith("issue-" + $n + "-"))
      or ((.body // "") | test("(?i)(closes|fixes|resolves) #" + $n + "([^0-9]|$)")))] | length' <<< "$open_prs")"
    if [[ "$has_pr" != "0" ]]; then
      log "#$n skipped: open PR exists"; continue
    fi

    if ! deps="$(parse_deps "$body")"; then
      log "#$n skipped: missing or malformed '## Depends on' section"; continue
    fi

    blocked=""
    while IFS= read -r d; do
      [[ -n "$d" ]] || continue
      state="$(gh issue view "$d" -R "$REPO" --json state -q .state)"
      if [[ "$state" != "CLOSED" ]]; then blocked="#$d is $state"; break; fi
    done <<< "$deps"
    if [[ -n "$blocked" ]]; then
      log "#$n skipped: dependency $blocked"; continue
    fi

    SELECTED="$n"
    return 0
  done < <(jq -c 'sort_by(.number)[]' <<< "$open_issues")

  return 0
}

# Block until the session is idle or terminated. On failure, set SESSION_PROBLEM and return 1.
wait_for_session() {
  local id="$1" deadline status
  deadline=$(( $(date +%s) + WAIT_TIMEOUT_SECONDS ))
  while :; do
    if ! status="$(ant beta:sessions retrieve --session-id "$id" --transform status --raw-output)"; then
      SESSION_PROBLEM="could not read the status of session $id"; return 1
    fi
    case "$status" in
      idle|terminated) return 0 ;;
    esac
    if (( $(date +%s) >= deadline )); then
      SESSION_PROBLEM="session $id did not finish within the wait timeout"; return 1
    fi
    sleep "$POLL_SECONDS"
  done
}

# Print the final Inner Loop result JSON for a session, or nothing if none is found.
final_result() {
  local id="$1" text
  text="$(ant beta:sessions:events list --session-id "$id" --type agent.message --order desc --limit 5 \
    | jq -r '[.. | objects | .text? // empty] | join("\n")')" || text=""
  grep -o '{[^{}]*"stage"[[:space:]]*:[[:space:]]*"inner-loop"[^{}]*}' <<< "$text" | tail -n1 || true
}

# Set STATUS, PR and PROBLEM for session $1. Anything other than a parseable
# result is "blocked", so the caller always gets an outcome it can act on.
read_outcome() {
  local id="$1" result parsed
  STATUS="blocked"; PR="null"; PROBLEM=""
  if ! wait_for_session "$id"; then
    PROBLEM="$SESSION_PROBLEM"; return 0
  fi
  result="$(final_result "$id")"
  if [[ -z "$result" ]]; then
    PROBLEM="no parseable final result from session $id"; return 0
  fi
  if ! parsed="$(jq -r '[.status // "blocked", (.pr // "null"), (.problem // "")] | @tsv' <<< "$result" 2>/dev/null)"; then
    PROBLEM="final result from session $id is not valid JSON"; return 0
  fi
  IFS=$'\t' read -r STATUS PR PROBLEM <<< "$parsed"
}

# Add the needs-human label unless the issue already has it. Only for non-done outcomes.
hold_issue() {
  local n="$1" labels
  gh label create "$LABEL" -R "$REPO" --color B60205 \
    --description "Driver stopped: needs a human before this issue is run again" >/dev/null 2>&1 || true
  labels="$(gh issue view "$n" -R "$REPO" --json labels -q '.labels[].name')"
  if grep -qx "$LABEL" <<< "$labels"; then
    log "#$n already labelled $LABEL"; return 0
  fi
  gh issue edit "$n" -R "$REPO" --add-label "$LABEL" >/dev/null
  log "#$n labelled $LABEL"
}

# Hold issue $1 unless the run finished with a PR (STATUS=done).
apply_outcome() {
  local n="$1"
  if [[ "$STATUS" == "done" ]]; then return 0; fi
  log "problem: $PROBLEM"
  hold_issue "$n"
}

main() {
  local dry_run=false session_id plan_args=() launches
  REPO="${1:-}"; shift || true
  [[ -n "$REPO" && "$REPO" == */* ]] || die "usage: run-next-issue.sh <owner/repo> [--dry-run]"
  [[ "${1:-}" == "--dry-run" ]] && dry_run=true
  for bin in gh ant jq; do command -v "$bin" >/dev/null 2>&1 || die "$bin not found on PATH"; done
  [[ -f claude-lock.json ]] || die "claude-lock.json not found; run from the repo root"
  [[ "$dry_run" == true || -n "${RUN_TOKEN:-}" ]] || die "RUN_TOKEN not set"

  select_issue
  if [[ -z "$SELECTED" ]]; then
    log "no eligible issue; nothing launched"
    echo "result=none" >> "${GITHUB_OUTPUT:-/dev/null}"
    return 0
  fi
  log "selected #$SELECTED"
  echo "selected=$SELECTED" >> "${GITHUB_OUTPUT:-/dev/null}"

  if [[ "$dry_run" == true ]]; then
    log "dry run: not launching"
    return 0
  fi

  launches="$(recent_launches)"
  if (( launches >= DAILY_RUN_CAP )); then
    die "daily cap reached ($launches live launches in 24h, cap $DAILY_RUN_CAP); not launching"
  fi

  [[ "$REQUIRE_PLAN_APPROVAL" == true ]] && plan_args+=(--require-plan-approval)
  if session_id="$(GITHUB_TOKEN="$RUN_TOKEN" _workflow/platform/run-issue.sh "$REPO" "$SELECTED" "${plan_args[@]}")"; then
    log "session $session_id started"
    read_outcome "$session_id"
  else
    session_id="none"; STATUS="blocked"; PR="null"; PROBLEM="could not start a session"
  fi

  log "#$SELECTED finished: status=$STATUS pr=$PR session=$session_id"
  echo "status=$STATUS" >> "${GITHUB_OUTPUT:-/dev/null}"
  echo "session=$session_id" >> "${GITHUB_OUTPUT:-/dev/null}"
  apply_outcome "$SELECTED"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
