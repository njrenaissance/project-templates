# Agent-Based Coding Workflow

## Principles

- **Determinism first.** Every stage has a defined input, process, and exit condition. Agents operate within guardrails, not open loops.
- **Minimize HITL.** Human-in-the-loop is the most expensive step. Only require it where human judgment is irreplaceable — planning approval and PR review.
- **AI fixes its own mess.** Pre-commit hooks and CI/CD must pass before a human ever sees the work. If they fail, the agent fixes and retries.
- **Context-free code review.** Code review subagents have no context from the build phase. They see only the diff — same as a fresh human reviewer would.
- **Gradual tool trust.** Tools start locked. A tool whitelist is expanded over time as confidence is established. Agents cannot use tools outside the whitelist without explicit approval.
- **Right model for the task.** Model selection is explicit per phase to avoid overspending on cheap tasks and underspending on critical ones.
- **Remote execution.** Automated phases (Build, Validate) run in cloud-isolated agent sandboxes via the Claude Agent SDK. The human's machine is never a dependency for these phases.
- **Async by default.** The human is notified only when a HITL gate is reached or a structured error halts the pipeline. No polling, no babysitting.

---

## The Workflow

### Phase 0 — Sequence `[Automated]`

**Goal:** Before any issue enters the pipeline, determine what can be built in parallel and what must be sequenced.

1. A **context-free sequencing subagent** receives the full list of open issues labeled `ready-to-plan` or `ready-to-build`.
2. It analyzes each issue for dependencies — shared modules, data model changes, API contracts, migration requirements — and produces:
   - A **dependency graph** (which issues block which)
   - A **parallel execution groups** list (issues with no interdependencies that can run simultaneously)
   - A **recommended build order** for sequenced issues
3. Output is written back to GitHub (e.g., as issue comments or labels) and used to schedule Phase 1 invocations.
4. This phase reruns whenever new issues are added to the queue.

**Model:** Reasoning-class — dependency inference requires understanding code relationships and risk, not just surface-level issue text.  
**Exit condition:** Dependency graph produced and build order established.

---

### Phase 1 — Plan `[HITL]`

**Goal:** Agree on what to build and how to verify it before writing any production code.

1. Human opens an issue describing the feature or fix.
2. Agent (reasoning model) reads the issue and proposes:
   - A plain-language implementation plan
   - A set of unit tests that define done (TDD)
3. Human reviews and iterates on both the plan and the tests until satisfied.
4. **Turn limit: 5 rounds of iteration.** If the plan has not been approved after 3 rounds, the issue is flagged as too large or too ambiguous. The agent halts planning, proposes how to split the issue into smaller, independently buildable sub-issues, and the human approves the split before any sub-issue re-enters Phase 1.
5. Human explicitly approves. This is the **last HITL gate until PR review.**

**Model:** Reasoning-class (e.g., claude-opus or equivalent) — this is where correctness matters most.  
**Exit condition:** Human approval of plan + unit tests. If turn limit hit: human approval of issue split, sub-issues created in GitHub, each re-enters Phase 0.

---

### Phase 2 — Scaffold `[Automated]`

**Goal:** Create a deterministic project structure if this is a new project.

1. Agent invokes the `scaffold-project` skill, which calls Cookiecutter with a locked template.
2. No agent decisions are made here — template is deterministic.
3. Pre-commit hooks are installed automatically as part of the scaffold.

**Model:** None / minimal (tool invocation only).  
**Exit condition:** Project directory created, pre-commit installed, CI config in place.

---

### Phase 3 — Build `[Automated]`

**Goal:** Write code that passes the approved unit tests.

1. Agent implements code against the approved plan and unit tests.
2. Agent may only use **whitelisted tools.** The whitelist is maintained separately and expanded deliberately over time.
3. Agent runs the approved unit tests locally in a loop until they pass.
4. Agent does not ask for human input. If it cannot proceed, it raises a structured error and halts.

**Model:** Code-generation class (e.g., claude-sonnet or equivalent) — balance of quality and cost.  
**Exit condition:** All approved unit tests pass locally.

---

### Phase 4 — Validate `[Automated]`

**Goal:** Ensure the code meets quality standards before any human sees it.

1. Pre-commit hooks run: linting, formatting, unit tests.
2. Agent pushes to a branch and CI/CD pipeline runs.
3. If any check fails, the agent diagnoses and fixes — no human involvement.
4. Retry loop continues until all checks pass or the retry limit is hit.
5. **Retry limit: 3 attempts.** After 3 failed attempts, the agent halts, preserves full context (error logs, last diff, attempted fixes), and sends an async notification. Rationale: a 4th attempt is unlikely to produce a different result, and continued retries waste cost without improving recoverability. The limit is tunable as failure patterns become understood.

**Model:** Light / fast model for diagnosis; same code-gen model for fixes.  
**Exit condition:** All pre-commit hooks and CI/CD checks pass cleanly.

---

### Phase 5 — Review `[Automated → HITL]`

**Goal:** Catch logic errors, security issues, and design problems that automated checks miss.

1. Agent opens a PR.
2. A **context-free subagent** (no knowledge of the build conversation) reviews the diff and leaves structured comments — logic, security, edge cases, adherence to plan.
3. Human reviews the PR and the subagent's comments.
4. Human approves or requests changes.
   - If changes requested → back to Phase 3 (Build), plan amendment optional.
   - If approved → merge.

**Model:** Reasoning-class for the review subagent — this is a critical thinking task.  
**Exit condition:** Human approval and merge.

---

## Cross-Cutting Concerns

Cross-cutting concerns (configuration, telemetry, logging, error handling, security, etc.) are **infrastructure-level standards**, not feature work. They are handled at two levels:

### 0. Project Design Prompt (Scaffold Time)

Before any code is written, the scaffold phase asks a small set of design questions that determine which cross-cutting concerns are active for this project. These are Cookiecutter prompt variables — answered once, baked into the project forever.

The scaffold prompt asks four independent `no`/`yes` toggles — each concern opts in on its own rather than being bundled into a fixed tier:

| Toggle | What it adds when `yes` |
|---|---|
| `app_config` | Application settings / config loading (`pydantic-settings`) |
| `structured_logging` | Structured logging (`structlog`) |
| `telemetry` | OpenTelemetry traces and metrics |
| `security` | Security scanning (`bandit`) plus input validation, secrets handling, and dependency-hygiene standards |

These selections determine:
- Which dependencies are added to the project
- Which standards documents are imported into `CLAUDE.md`
- Which `foundational` issues are auto-created in GitHub
- What the review subagent checks for in Phase 5

All decisions are recorded in `CLAUDE.md` (see its `## Profile` section) so every agent knows the project's active concerns without asking.

### 1. Standards Documents (Template → `CLAUDE.md`)

Every project template ships with a set of standards documents covering each cross-cutting concern. These are imported into `CLAUDE.md` so every agent reads them automatically on every invocation — no explicit referencing required.

The template ships standards documents for every concern. Some are imported into `CLAUDE.md` unconditionally; the rest are gated on the matching toggle:

| File | Imported |
|---|---|
| `.claude/standards/git-workflow.md` | always |
| `.claude/standards/wiki.md` | always |
| `.claude/standards/testing.md` | always |
| `.claude/standards/error-handling.md` | always |
| `.claude/standards/logging.md` | always (self-gates `structlog` vs stdlib on `structured_logging`) |
| `.claude/standards/configuration.md` | when `app_config` is `yes` |
| `.claude/standards/telemetry.md` (OTEL) | when `telemetry` is `yes` |
| `.claude/standards/security.md` | when `security` is `yes` |

Each standards document is prescriptive in two ways:

1. **How** — patterns, conventions, and rules agents must follow
2. **What** — the specific Python libraries approved for that concern (no agent should substitute its own choice)

The Cookiecutter template uses conditional logic to inject the correct dependencies into `pyproject.toml` (or `requirements.txt`) based on the toggles selected at scaffold time. An agent never decides which logging or telemetry library to use — that decision is made once in the standard and enforced by the template.

Example standard library assignments (subject to revision):

| Concern | Approved libraries |
|---|---|
| App settings / config | `pydantic-settings` (with `python-dotenv` for `.env` support, used transitively) |
| Structured logging | `structlog` |
| OpenTelemetry | `opentelemetry-sdk`, `opentelemetry-api`, relevant exporters |
| Security | `bandit` (static analysis) |
| Testing | `pytest`, `pytest-cov`, `pytest-mock` |

These documents are **prescriptive** — they define how things must be done across all projects. They evolve slowly and intentionally; changes to a standard (including library upgrades) are made in the template and consciously adopted by new projects.

### 2. Foundational Issues

Cross-cutting concerns that require actual implementation work (e.g., "Set up telemetry framework", "Define config loading strategy") are created as GitHub issues labeled `foundational`. The Phase 0 sequencing subagent always schedules `foundational` issues before any feature work — nothing builds on top of infrastructure that doesn't exist yet.

---

## Codebase Wiki (`openwiki/`)

Every project maintains an `openwiki/` folder as the shared memory for all agents. It is generated by **OpenWiki** — an LLM-powered CLI (`npm install -g openwiki`) that produces structured Markdown documentation from the codebase. The `openwiki/` content is **generated output — never hand-edited**; the source of truth is always the code itself. The agent-facing rule lives in the generated project's `.claude/standards/wiki.md`; per-machine install and usage are documented in its `README`.

### Why OpenWiki

Evaluated against the Gideon codebase, OpenWiki produced output that:

- Correctly identified module boundaries, key abstractions, and security-critical components
- Generated a `source-map.md` mapping every file to its purpose and related wiki pages — directly usable by the Phase 0 sequencing agent
- Produced workflow and architecture docs specific enough to guide Phase 1 planning and Phase 3 building
- Regenerates from a single command (`openwiki code --update`), so refreshing it is one deterministic step rather than a manual doc-writing chore

This is better than agents maintaining wiki docs manually: it's deterministic, consistent, and always reflects the actual code.

### Structure

OpenWiki generates a consistent folder structure:

| Path | Contents |
|---|---|
| `openwiki/source-map.md` | Maps every file to its purpose and related wiki pages; includes "I want to..." task index |
| `openwiki/architecture/overview.md` | Service layers, tech stack, key abstractions, security invariants |
| `openwiki/architecture/flows.md` | Data flow diagrams and walkthroughs |
| `openwiki/architecture/permission-model.md` | Role definitions, access control rules |
| `openwiki/workflows/` | Per-workflow docs (auth, ingestion, RAG query, etc.) |
| `openwiki/operations/` | Deployment, configuration, background jobs |
| `openwiki/testing/overview.md` | Test structure, fixtures, coverage approach |

### Who Reads It

Every agent reads the relevant wiki documents at the start of its invocation:

- **Phase 0 (Sequence)** — `source-map.md` + `architecture/overview.md` to infer issue interdependencies
- **Phase 1 (Plan)** — full wiki for context before proposing a plan and tests
- **Phase 3 (Build)** — `source-map.md` + relevant workflow doc to write consistent code
- **Phase 5 (Review)** — `architecture/overview.md` to assess adherence to established patterns and security invariants

### Who Writes It

OpenWiki is the only writer. For now, regeneration is a **manual step**: before committing a change, the developer or agent runs `openwiki code --update` and commits the refreshed `openwiki/` in the same pull request, so the wiki never drifts from `main`. Nobody hand-edits `openwiki/` — corrections to the wiki are corrections to the code, followed by a regenerate. Automating this in CI (a workflow that regenerates the wiki and opens a PR on merge to main) is a **deferred future goal**, not yet wired up.

### Setup

The `openwiki` CLI is a global npm tool (`npm install -g openwiki`) that developers install once per machine, then authenticate once (`openwiki auth <provider>`); it is not a project dependency and does not appear in `pyproject.toml`. First run in a fresh repo uses `openwiki code --init`; subsequent refreshes use `openwiki code --update`. The template documents this in the generated project's `README` (`## Wiki` section) and enforces the regenerate-before-commit rule via `.claude/standards/wiki.md`. (A pre-configured CI workflow was considered and deferred — see "Who Writes It" above.)

---

## Tool Whitelist Policy

Tools available to agents are locked by default. A tool is added to the whitelist only after:

1. It has been used successfully in a supervised (HITL) context.
2. There is confidence its failure modes are understood and recoverable.

The whitelist is stored per project in `.claude/settings.json` and versioned with the code. This means tool trust is explicit, auditable, and scoped.

### Two-tier whitelist

**Template-level (Cookiecutter default):** The project template ships with a baseline set of pre-approved tools in `.claude/settings.json` — tools that have proven safe and useful across all projects. When a new project is scaffolded, it inherits this baseline automatically.

**Project-level (per-project extension):** Individual projects can add tools to the whitelist beyond the template baseline, stored in the same `.claude/settings.json`. These are specific to that project and do not affect others.

### Promoting a tool to the template

When a project-level tool proves reliable across multiple projects, it can be promoted to the template baseline:

1. Update the Cookiecutter template's `.claude/settings.json` to include the tool.
2. Existing projects retain their own settings and are not auto-updated — promotion only affects new projects going forward.

This creates a ratchet: tools earn trust in individual projects first, then graduate to the shared template over time.

---

## Model Selection Guide

| Phase | Task complexity | Recommended tier |
|---|---|---|
| Sequence subagent | High — dependency inference | Reasoning-class |
| Plan | High — reasoning, ambiguity | Reasoning-class |
| Scaffold | Trivial — tool invocation | Minimal / none |
| Build | Medium — code generation | Mid-tier |
| Validate (diagnosis) | Low — pattern matching | Fast / cheap |
| Review subagent | High — critical analysis | Reasoning-class |

---

## Remote Execution & Async Notification

### Execution Model

Phases 3 (Build) and 4 (Validate) run as remote agents using the **Claude Agent SDK with `isolation: "remote"`**. This means:

- The agent runs in a cloud sandbox — no dependency on the human's local machine.
- The human can trigger a session from anywhere (laptop, phone, etc.) and walk away.
- Each phase is a discrete agent invocation with a defined input and exit condition, so failures are isolated and restartable.

Phase 1 (Plan) and Phase 5 (Review) require HITL and run locally or via a lightweight interface where the human can respond.

### Triggering

A coding session can be triggered from anywhere — no local machine required:

- **GitHub-driven** — human creates or updates an issue, or applies a label (e.g., `ready-to-plan` or `ready-to-build`). A GitHub webhook fires and kicks off the appropriate phase.
- **Manual remote** — human sends a command from any device (e.g., a lightweight UI, Slack command, or CLI against an API endpoint) to trigger a specific phase.
- **Post-approval continuation** — after the human approves Phase 1, the pipeline automatically advances to Phase 3 without any additional trigger.

The intent is that the human's only required interactions are: (1) create/label a GitHub issue and (2) respond to async notifications at HITL gates.

### Notification Events

The human is notified asynchronously at these points only:

| Event | Notification | Action required |
|---|---|---|
| Phase 1 ready for review | Agent posts plan + unit tests | Human reviews and approves or iterates |
| Phase 3/4 error (retry limit hit) | Agent posts structured error report | Human investigates and decides next step |
| Phase 5 PR ready | Agent posts PR + review subagent comments | Human reviews and approves or requests changes |

Notification channel: **GitHub comments**. The agent posts a structured comment on the relevant issue or PR at each HITL gate. This keeps all context in one place and requires no extra infrastructure. A consistent comment format (e.g., a `[HITL]` prefix) distinguishes action-required notifications from regular activity. Human responds by commenting or applying a label directly in GitHub.
