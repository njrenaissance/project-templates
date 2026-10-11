# ADR 0001: Deterministic driver for the Inner Loop, started on demand

Status: accepted. Tracked by issue #52. Spec: [driver-spec.md](../platform/driver-spec.md).

## Context

The Inner Loop (`_workflow/platform/agents/inner-loop.yml`) works one GitHub issue with a managed-agent session. Something has to decide which issue runs next and launch it. The first trigger is on demand, started from the phone. Later triggers are scheduled runs and PR merges.

## Decision

Build a deterministic driver, not an LLM orchestrator. `_workflow/platform/run-next-issue.sh` picks the issue, launches the Inner Loop through `run-issue.sh`, reads the result, and labels the issue. A `workflow_dispatch` GitHub Action (`.github/workflows/run-next-issue.yml`) runs it.

Selection is the lowest-numbered open issue where:

1. every issue under `## Depends on` is closed (merged, not just a PR opened);
2. no open PR exists for it, matched by branch `issue-<n>-*` or a `Closes/Fixes/Resolves #<n>` body;
3. it does not carry the `needs-human` label.

If nothing qualifies, the driver reports why and stops.

Only a `done` result leaves an issue open for review, as a draft PR. Every other outcome adds `needs-human`. Without that label the selection rule would pick the same issue on the next run. A human removes the label to re-enable an issue.

Each live run carries `(live)` in its run-name. The daily cap (default 3 launches in a rolling 24h) counts only those runs, so dry runs do not use up the cap.

First live runs require plan approval (`--require-plan-approval`). The Inner Loop stops at `awaiting_approval`, and the issue is labelled `needs-human` until a human approves the plan.

## Alternatives considered

- **LLM orchestrator** that reads the backlog and picks the next issue. Rejected. The rule is fully deterministic, so an LLM adds cost and nondeterminism without adding judgment. Revisit only if the rule is observed to pick the wrong issue.
- **Local script only.** Rejected for the first trigger. The phone trigger needs Actions. The script stays runnable locally, since the workflow calls the same file.

## Consequences

- Chaining runs from a workflow (scheduled or on merge) needs a PAT or GitHub App token. Events created by `GITHUB_TOKEN` do not start other workflows. That is deferred to the later triggers.
- `issue-decomposition` must write a `## Depends on` section in every issue. Without it, the driver skips the issue and reports it.
- A live run that selects nothing still counts toward the cap. This is a known over-count, accepted for simplicity.
- The result parser and the session status field are unverified until the first live run. Those are the open checks in issue #52.
