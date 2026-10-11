# ADR 0001: Deterministic driver for the Inner Loop, started on demand

Status: accepted (amended 2026-10-11). Tracked by issue #52. Spec: [driver-spec.md](../platform/driver-spec.md).

## Context

The Inner Loop (`_workflow/platform/agents/inner-loop.yml`) works one GitHub issue with a managed-agent session. Something has to decide which issue runs next and launch it. The first trigger is on demand. Later triggers are scheduled runs and PR merges.

## Decision

Build a deterministic driver, not an LLM orchestrator. `_workflow/platform/run-next-issue.sh` reconciles the single-flight lock, picks the issue, and launches the Inner Loop through `run-issue.sh`. A central `workflow_dispatch` GitHub Action in `project-templates` (`.github/workflows/run-next-issue.yml`) runs it, with the target repo as an input.

Selection is the first open issue where:

1. every issue under `## Depends on` is closed (merged, not just a PR opened);
2. no open PR exists for it, matched by branch `issue-<n>-*` or a `Closes/Fixes/Resolves #<n>` body;
3. it carries neither `needs-human` nor `agent-running`.

Among eligible issues, `urgent` comes first, then `bug`, then lowest number. If nothing qualifies, the driver reports why and stops.

A single-flight lock is the `agent-running` label, set at launch and global across repos. It is cleared when the issue gets a PR, and held with `needs-human` when the session ends without one. Each run reconciles the lock before selecting. The driver never waits for a session.

Plan approval is off. The draft PR is the human gate.

## Alternatives considered

- **LLM orchestrator** that reads the backlog and picks the next issue. Rejected. The rule is fully deterministic, so an LLM adds cost and nondeterminism without adding judgment. Revisit only if the rule is observed to pick the wrong issue.
- **Daily launch cap counted from run-names.** Rejected in the amendment. It was fragile, over-counted, and needed a result parser to be right. The single-flight lock limits concurrency more simply.
- **Plan approval with a resume path.** Deferred. Nothing in the driver could resume an `awaiting_approval` run, so an issue would stay held forever. The draft PR gives the same human checkpoint.
- **Wait for the session in Actions.** Rejected. It held a job open for hours and depended on an unverified status field. Reconcile on the next run does the same job.
- **Per-repo workflow copies.** Rejected. Each repo would need its own secrets and workflow. One central workflow takes the repo as input.
- **Local script only.** Rejected for the first trigger. The on-demand trigger needs Actions. The script stays runnable locally, since the workflow calls the same file.

## Consequences

- Chaining runs from a workflow (scheduled or on merge) needs a PAT or GitHub App token. Events created by `GITHUB_TOKEN` do not start other workflows. That is deferred to the later triggers.
- The vault's GitHub credential is one identity. It must reach every target repo, and its blast radius spans them all. A GitHub App (issue #37) would scope it down.
- `issue-decomposition` must write a `## Depends on` section in every issue. Without it, the driver skips the issue and reports it.
- The session status field and the session-to-issue comment mapping are unverified until the first live run.
- Search index lag can briefly hide a fresh lock from `gh search issues`. Accepted for now.
