# Claude Platform resources

Definitions for the stage that runs as a Claude **Managed Agent** on the Claude
Platform. Currently one: `agents/inner-loop.yml`, which runs the whole Inner Loop
(Plan Issue -> Write Tests -> Build -> open PR) for a single issue in one
unattended session. It never merges; the human reviews the PR. See
`../coding-workflow.md` for where it fits.

Every other stage (Plan, Bootstrap, Sequence) is an interactive Claude Code
session, not a managed agent.

## Layout

```text
platform/
  agents/inner-loop.yml                  # the Inner Loop agent
  run-issue.sh                           # launch a run: repo + issue number
  environments/coding-workflow.yml       # environment "coding-workflow-env"
```

`ant apply` infers each file's kind from its directory (`agents/`,
`environments/`), so keep that layout.

## Applying

From the repo root (needs the `ant` CLI, 1.30.0 or later, and authentication):

```bash
ant apply --dry-run _workflow/platform   # preview the plan
ant apply _workflow/platform             # create/update, then approve the plan
```

Commit the `claude-lock.json` it writes; it is how the next run updates the same
agent and environment instead of creating duplicates. It is tied to one
organization and workspace. The agent and environment IDs used below are in it.

## Launching a run

Give it a repo and an issue number:

```bash
export GITHUB_TOKEN=<fine-grained PAT for the target repo>
_workflow/platform/run-issue.sh njrenaissance/argparslib 4
# add --require-plan-approval to stop after the plan is posted
```

Run it from the repo root after `ant apply`. It prints the session ID; follow
progress with `ant beta:sessions:events list --session-id <id>`.

What the script does, in one `ant beta:sessions create` call:

- **Agent and environment** — the IDs are read from `claude-lock.json`.
- **Repo** — mounted as a `github_repository` resource (cloned at the default
  branch under `/workspace/<repo-name>`) using `GITHUB_TOKEN`. A mount is a
  session-creation parameter, so whoever creates the session must supply it; a
  future orchestrator would do the same. Mounting also loads any skills in the
  repo's root `.claude/skills`.
- **Vault** — `vlt_011Cdb285v3WU3iywUaK3jSG` is attached via `vault_ids`. It is not
  defined in this repo.
- **Kickoff message** — `repo`, `issue`, `require_plan_approval`. With
  `require_plan_approval` true the run stops after posting the plan with status
  `awaiting_approval`; once you approve, start a new session with
  `approved_plan: <comment URL>` in the message and it resumes from the build.

### Why a session, not a deployment

A Claude Platform *deployment* runs an agent in an environment on a cron schedule
with one fixed initial message, and its manual `run` call takes no parameters. The
Inner Loop needs a different `repo` and `issue` each run, so it is launched as a
session. A deployment would only suit an unattended variant (for example a
nightly "pick the oldest open issue" run).

### Credentials

- **Vault** — one `static_bearer` credential for the GitHub MCP server,
  `https://api.githubcopilot.com/mcp/`. The agent uses the MCP tools for issue
  comments and pull requests. Credentials live only in the vault, never in this
  repo or the YAML.
- **Repo token** — passed per session as the `github_repository` resource's
  `authorization_token` (see above); it clones the repo and is what `git` uses.
  Use a fine-grained PAT scoped to the target repo.
- `gh` is not used and not installed. If `git push` turns out to have no write
  credentials in the sandbox, the agent falls back to pushing through the MCP
  tools (`create_branch`, `push_files`) and says so in the PR body.

## Result

The run ends with a structured result:
`{"stage":"inner-loop","repo":...,"issue":...,"status":...,"pr":...,"plan_comment":...,"problem":...}`
where `status` is `done`, `blocked` (plan too big/vague, or other stop),
`awaiting_approval`, or `escalated` (gate still red after 3 attempts).

## Not covered (deliberately)

- No context-free review subagent, no test-integrity hash lock, no Scrum Master,
  no dependency/build order. Code Review is the human reading the draft PR.
