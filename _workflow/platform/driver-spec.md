# Driver spec: "run next issue"

Status: built (v2), not yet run live. Decision record: [ADR 0001](../adr/0001-run-next-issue-driver.md), as amended. Tracked by issue #52.

## Purpose

A deterministic driver that picks the next eligible issue and launches the Inner Loop managed agent (`agents/inner-loop.yml`) on it. It is not an LLM. The only LLM work is inside the Inner Loop run.

It runs as one central workflow in `project-templates` and takes the target repo as input, so there is one set of secrets and no per-repo copy. First trigger: `workflow_dispatch`. Later: scheduled, and on PR merge.

The driver never waits for a session. It launches, records the session, and exits. The Inner Loop reports its own outcome: a draft PR on `done`, or a comment on the issue otherwise.

## Selection rule

Among open issues in the target repo, pick the first one (in this order of priority) where all of these hold:

1. Every issue listed under `## Depends on` is closed. Closed means merged, not just a PR opened.
2. No open PR already exists for the issue. A PR matches by branch `issue-<n>-*` or a `Closes/Fixes/Resolves #n` body.
3. The issue carries neither `needs-human` nor `agent-running`.

Ordering among eligible issues: `urgent` label first, then `bug`, then lowest number.

If nothing qualifies, report why and stop. Do not guess.

## Single-flight lock

The `agent-running` label marks the one live run. It is global across every repo the owner has: at most one issue carries it at a time.

- **Set** at launch, before the session starts. If the launch fails, the label is removed.
- **Session ID** is recorded as a comment on the issue (`Inner Loop session <id> started by the driver.`). That comment is the only issue-to-session link, so no state file is kept.
- **Reconcile first, every run.** Before selecting, the driver checks each issue that holds the label:
  - open PR exists → remove `agent-running` (a human now reviews it);
  - session `idle` or `terminated` with no PR → add `needs-human`, remove `agent-running`;
  - session still running, or its status cannot be read → leave the label and stop (lock held);
  - no session comment → add `needs-human`, remove `agent-running`.

Reconcile replaces the result parser and the daily run counter.

## Outcome handling

No result parsing. The Inner Loop's outcome is visible on the issue and in its PR:

| Result (what the reconcile sees) | Driver action |
|---|---|
| Draft PR open | Release the lock. Nothing else. The PR is not merged. |
| Session ended, no PR | Add `needs-human` (the run was blocked, escalated, or awaiting approval). |
| Session running | Hold the lock. |

The driver adds `needs-human` only through reconcile, and only once per issue. A human removes the label to make an issue eligible again.

## Approval

Plan approval is off. Runs go straight to tests, build, review, and a draft PR. The draft PR is the human gate. The driver never passes `--require-plan-approval`. The flag stays in `run-issue.sh` and the agent for manual runs.

## Controls

- **Single-flight.** One live run at a time, across all repos. The workflow's concurrency group also prevents two driver runs at once.
- **Dry run.** `dry_run` defaults to true. A dry run reports the selection and the reconcile decisions and writes nothing.
- **Credentials.** `GH_TOKEN` must reach the target repo and read its issues and PRs. `RUN_TOKEN` is the token each session mounts the repo with. Both come from Actions secrets, or from the operator's environment when run locally. Never in the repo.
- **Vault.** The GitHub MCP credential in the vault is one identity. It must be able to comment on and open PRs in every target repo.

## Files

- `_workflow/platform/run-next-issue.sh`: reconcile, selection, launch.
- `_workflow/platform/test-run-next-issue.sh`: unit tests with `gh` and `ant` stubbed.
- `.github/workflows/run-next-issue.yml`: `workflow_dispatch` with `repo` and `dry_run` inputs.

## Prerequisites

- Label `urgent` exists in each target repo. The driver does not create it; it is a human-set priority.
- `agent-running` and `needs-human` are created on first use (the script creates them).
- Issue #40 (refresh the cached checkout) is closed. Step 0 of `inner-loop.yml` already has the refresh.
- `issue-decomposition` writes `## Depends on` in every issue. Without it, every issue is skipped.

## Open until the first live run

- The session status field read by `ant beta:sessions retrieve --transform status`. Confirm against a real session before relying on reconcile.
- The session-to-issue comment mapping. If session metadata can carry the issue number, prefer it.
- `ANT_DOWNLOAD_URL` (the Linux `ant` archive URL in the workflow). Not yet confirmed.
- Search index lag. The lock check uses `gh search issues`, which can miss a label set moments ago. The concurrency group covers the driver's own runs, but a manual issue edit could race.
