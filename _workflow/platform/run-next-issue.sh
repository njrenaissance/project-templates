#!/usr/bin/env bash
#
# run-next-issue.sh — pick the next eligible issue and launch the Inner Loop on it.
#
# Selection rule, lock, and outcome handling: _workflow/platform/driver-spec.md.
# Runs from the repo root. Requires: gh (authenticated via GH_TOKEN), ant, jq,
# and claude-lock.json at the repo root.
#
# Usage:
#   GH_TOKEN=<token> RUN_TOKEN=<repo PAT> ANTHROPIC_API_KEY=<key> \
#     _workflow/platform/run-next-issue.sh <owner/repo> [--dry-run]
#
# GH_TOKEN must reach the target repo and its owner's issues (label search).
# RUN_TOKEN is the token each Inner Loop session mounts the repo with.
#
# The driver never waits for a session. It reconciles the single-flight lock
# (the agent-running label) on the next run, from the PR and session state.

set -euo pipefail

LOCK_LABEL="agent-running"
HOLD_LABEL="needs-human"
DRY_RUN=false
LOCKED=false
SELECTED=""

log() { printf 'run-next-issue: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }
output() { echo "$1" >> "${GITHUB_OUTPUT:-/dev/null}"; }

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

fetch_open_prs() { gh pr list -R "$1" --state open --limit 500 --json number,headRefName,body; }

# Count open PRs in $1 (JSON from fetch_open_prs) that belong to issue $2.
open_pr_count() {
  jq -r --arg n "$2" '[.[] | select((.headRefName | startswith("issue-" + $n + "-"))
    or ((.body // "") | test("(?i)(closes|fixes|resolves) #" + $n + "([^0-9]|$)")))] | length' <<< "$1"
}

# Add a label to an issue, creating the label first if the repo lacks it.
add_label() { # repo number label
  gh label create "$3" -R "$1" --color B60205 --description "Inner Loop driver: $3" >/dev/null 2>&1 || true
  gh issue edit "$2" -R "$1" --add-label "$3" >/dev/null
}

clear_lock() { # repo number
  if [[ "$DRY_RUN" == true ]]; then log "dry run: would clear $LOCK_LABEL on $1#$2"; return 0; fi
  gh issue edit "$2" -R "$1" --remove-label "$LOCK_LABEL" >/dev/null
}

# Hold an issue for a human: add needs-human (once) and release the lock.
hold_issue() { # repo number reason
  if [[ "$DRY_RUN" == true ]]; then log "dry run: would hold $1#$2 ($3)"; return 0; fi
  local labels
  labels="$(gh issue view "$2" -R "$1" --json labels -q '.labels[].name')"
  if ! grep -qx "$HOLD_LABEL" <<< "$labels"; then
    add_label "$1" "$2" "$HOLD_LABEL"
    gh issue comment "$2" -R "$1" --body "Inner Loop driver: $3. Remove \`$HOLD_LABEL\` to make this issue eligible again." >/dev/null
    log "$1#$2 held: $3"
  fi
  clear_lock "$1" "$2"
}

# Print the session ID the driver recorded on an issue, or nothing.
session_of() { # repo number
  gh issue view "$2" -R "$1" --json comments -q '.comments[].body' \
    | grep -o 'Inner Loop session [A-Za-z0-9_-]*' | tail -n1 | awk '{print $4}' || true
}

session_status() { # session id -> idle | running | terminated | ...
  ant beta:sessions retrieve --session-id "$1" --transform status --raw-output
}

# Reconcile every issue that holds the lock, across all repos the owner has.
# Sets LOCKED=true while a live run still holds it.
reconcile() {
  local hits repo n prs session status
  LOCKED=false
  hits="$(gh search issues --label "$LOCK_LABEL" --owner "${REPO%%/*}" --state open \
    --json repository,number -q '.[] | "\(.repository.nameWithOwner) \(.number)"')"
  while read -r repo n; do
    [[ -n "$repo" ]] || continue
    prs="$(fetch_open_prs "$repo")"
    if [[ "$(open_pr_count "$prs" "$n")" != "0" ]]; then
      log "$repo#$n has an open PR: releasing the lock"
      clear_lock "$repo" "$n"; continue
    fi
    session="$(session_of "$repo" "$n")"
    if [[ -z "$session" ]]; then
      hold_issue "$repo" "$n" "holds the lock but no session is recorded"; continue
    fi
    if ! status="$(session_status "$session")"; then
      log "$repo#$n: could not read session $session; lock held"
      LOCKED=true; return 0
    fi
    case "$status" in
      idle|terminated) hold_issue "$repo" "$n" "session $session ended without an open PR" ;;
      *) log "$repo#$n: session $session is $status; lock held"; LOCKED=true; return 0 ;;
    esac
  done <<< "$hits"
}

# Set SELECTED to the next eligible issue. Print a reason for every skip.
# Order: urgent first, then bugs, then lowest number.
select_issue() {
  local open_issues open_prs issue n body deps d state blocked
  open_issues="$(gh issue list -R "$REPO" --state open --limit 500 --json number,body,labels)"
  open_prs="$(fetch_open_prs "$REPO")"
  SELECTED=""

  while IFS= read -r issue; do
    n="$(jq -r '.number' <<< "$issue")"
    body="$(jq -r '.body // ""' <<< "$issue")"

    if jq -e --arg l "$HOLD_LABEL" --arg k "$LOCK_LABEL" 'any(.labels[]?; .name == $l or .name == $k)' <<< "$issue" >/dev/null; then
      log "#$n skipped: has $HOLD_LABEL or $LOCK_LABEL label"; continue
    fi

    if [[ "$(open_pr_count "$open_prs" "$n")" != "0" ]]; then
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
  done < <(jq -c 'map(. + {rank: ((if any(.labels[]?; .name == "urgent") then 0 else 1 end) * 2
      + (if any(.labels[]?; .name == "bug") then 0 else 1 end))})
    | sort_by(.rank, .number)[]' <<< "$open_issues")

  return 0
}

# Start the Inner Loop on issue $2 of repo $1. Lock first, so a failed launch
# cannot leave a live run unmarked. Record the session ID for the next reconcile.
launch_issue() { # repo number
  local session
  if ! add_label "$1" "$2" "$LOCK_LABEL"; then die "could not set $LOCK_LABEL on $1#$2"; fi
  if ! session="$(GITHUB_TOKEN="$RUN_TOKEN" _workflow/platform/run-issue.sh "$1" "$2")"; then
    clear_lock "$1" "$2"; die "could not start a session for $1#$2"
  fi
  gh issue comment "$2" -R "$1" --body "Inner Loop session $session started by the driver." >/dev/null
  log "$1#$2 running in session $session"
  output "session=$session"
}

main() {
  REPO="${1:-}"; shift || true
  [[ -n "$REPO" && "$REPO" == */* ]] || die "usage: run-next-issue.sh <owner/repo> [--dry-run]"
  [[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
  for bin in gh ant jq; do command -v "$bin" >/dev/null 2>&1 || die "$bin not found on PATH"; done
  [[ -f claude-lock.json ]] || die "claude-lock.json not found; run from the repo root"
  [[ "$DRY_RUN" == true || -n "${RUN_TOKEN:-}" ]] || die "RUN_TOKEN not set"

  reconcile
  if [[ "$LOCKED" == true ]]; then
    log "single-flight lock held; nothing launched"
    output "result=locked"; return 0
  fi

  select_issue
  if [[ -z "$SELECTED" ]]; then
    log "no eligible issue; nothing launched"
    output "result=none"; return 0
  fi
  log "selected $REPO#$SELECTED"
  output "selected=$SELECTED"

  if [[ "$DRY_RUN" == true ]]; then
    log "dry run: not launching"; return 0
  fi
  launch_issue "$REPO" "$SELECTED"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
