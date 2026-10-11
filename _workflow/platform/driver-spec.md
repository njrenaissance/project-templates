# Driver spec: "run next issue"

Status: built (v1), not yet run live. Decision record: [ADR 0001](../adr/0001-run-next-issue-driver.md). Tracked by issue #52.

## Purpose

A deterministic driver that picks the next issue to work and launches the Inner Loop managed agent on it (`agents/inner-loop.yml`). It is not an LLM. The only LLM work is inside the Inner Loop run.

First trigger: on demand ("run next issue", started from the phone). Later: scheduled, and on PR merge.

## Selection rule

Pick the lowest-numbered open issue where all of these hold:

1. Every issue listed under `## Depends on` is closed. Closed means merged, not just a PR opened.
2. No open PR already exists for the issue.
3. The issue does not carry the `needs-human` label.

If nothing qualifies, report why and stop. Do not guess.

## Outcome handling

The Inner Loop ends with one structured result (`inner-loop.yml`, step 8):
`{"stage":"inner-loop","repo":...,"issue":...,"status":...,"pr":...,"plan_comment":...,"problem":...}`

Only `done` opens a PR. The other statuses can leave an issue with no PR, so the selection rule alone would pick the same issue again on the next run. The driver must therefore label every non-`done` outcome:

| Result | Driver action |
|---|---|
| `done` (draft PR, `pr` set) | Record the run. Nothing else. The PR is a draft and not merged. |
| `blocked` | Add `needs-human` to the issue. |
| `escalated` | Add `needs-human` to the issue. The agent has already pushed the branch and commented. |
| `awaiting_approval` | Add `needs-human` to the issue. The human approves the plan and starts a new session with `approved_plan`. |
| No result, unparseable result, or session error | Treat as `blocked`. Add `needs-human` and record the raw error. |

Re-enabling an issue is a human action: remove the `needs-human` label after resolving the problem. The driver never removes the label itself.

The driver must check for the label before adding it, so repeat runs are idempotent.

## Reading the result

`run-issue.sh` prints only the session ID. The driver must read the final result from session events, for example with `ant beta:sessions:events list --session-id <id>`, and parse the JSON from the last agent message. If the result cannot be parsed, use the "No result" row above.

## Controls (v1)

- **Hard cap on runs per day.** Stop when the cap is reached. The cap counts live runs in the rolling 24h window, identified by the `(live)` run-name tag. Dry runs are not counted. No state file.
- **Plan approval.** Launches pass `--require-plan-approval` unless `REQUIRE_PLAN_APPROVAL=false`. The workflow input defaults to true.
- **Single-flight.** Only one driver run at a time.
- **Credentials.** The Anthropic key and GitHub token come from Actions secrets when the driver runs in Actions, or from the operator's environment when it runs from a script. Never in the repo.
- **Stop conditions.** A blocked or failed run, a `needs-human` label, or an unmerged PR stops the driver. Dependents cannot start anyway, because their prerequisites are not closed.

## What has to be built

1. **Label.** Create `needs-human` in `njrenaissance/project-templates` if it does not exist. The token needs issue write scope to add labels.
2. **Dependency parser.** Read `## Depends on` from each open issue body. Accept issue numbers or `None`. Fail loudly on anything else. This depends on `issue-decomposition` writing the section (see the decision record's prerequisites).
3. **Selector.** Apply the three-part rule above and return the chosen issue or the reason nothing qualified.
4. **Launcher.** Wrap `run-issue.sh`, or call it, and capture the session ID.
5. **Result reader.** Fetch the session's final result and parse the JSON.
6. **Labeler.** Apply the outcome table, with the idempotency check.
7. **Run counter and cap.** Count runs per day, enforce the cap, and stop when it is hit.
8. **Entry point for the phone.** One command or workflow that runs steps 3 to 7 end to end. The Actions-versus-script choice is still open.
9. **Tests.** Selector and outcome-table unit tests against fixture issues and fixture results. No live runs in tests.

## Prerequisites

- Issue #40 (refresh the cached checkout before planning). Step 0 of `inner-loop.yml` already has the refresh in the committed file. Confirm #40 is closed before the first driver run.
- `issue-decomposition` writes `## Depends on` in every issue. Draft exists, not filed.

## Resolved and open questions

- Resolved: the run counter lives in run-names (`(live)` tag), not a state file.
- Resolved: the entry point is a `workflow_dispatch` Action (`run-next-issue.yml`). The script also runs locally.
- Resolved: `awaiting_approval` gets `needs-human`, so the driver holds the issue until a human acts.
- Open until the first live run: the session status field read by `ant beta:sessions retrieve --transform status`, and the event shape read by `final_result`.
