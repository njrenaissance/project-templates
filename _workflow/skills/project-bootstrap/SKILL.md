---
name: project-bootstrap
description: Use this skill to bootstrap a brand-new project end to end, in one Claude Code session, from an approved specification (SPEC.md and ADRs.md, produced during Plan). Creates the GitHub repo, renders the chosen Cookiecutter template into it, copies in the approved spec as spec/SPEC.md and any ADRs, pushes straight to main, and only then turns on branch protection -- no PR for this step. This is a mechanical step (rendering a known template into a known folder), not a judgment call, so it skips the two-session admin/content split and PR gate used elsewhere in the outer loop. Trigger whenever the task is bootstrapping a new project's repo and structure from an approved spec. Does not decompose issues or write application code -- those come after, in separate sessions.
allowed-tools: Read Write Glob Bash(gh repo create:*) Bash(gh label create:*) Bash(gh api repos/*/branches/*/protection) Bash(git clone:*) Bash(git add:*) Bash(git commit:*) Bash(git push:*) Bash(gh repo clone:*) Bash(gh api repos/*/contents*)
---

# Project Bootstrap

## When this applies

This is the first Claude Code session for a brand-new project. The approved spec and any ADRs already
exist (written during Plan, as a Claude doc). No GitHub repo
exists yet -- this session creates it. Do not use this skill against a repo
that already has project structure in it.

## Step 1 -- Create the repo (main left open)

1. Read SPEC.md for the project name; derive the repo slug from it.
2. `gh repo create <org>/<slug> --private` (or `--public`, per SPEC.md / the
   human's stated preference).
3. Seed the workflow's standard labels (`gh label create ...`), matching the
   label set the Execution phase's issues expect.
4. Do NOT protect `main` yet -- "require PR before merging" would block
   Step 3's direct push. Protection is the last step of this skill, after
   content is already on `main`.

Credential handling: this session authenticates to GitHub through Claude
Code's own GitHub proxy (via the Claude GitHub App or `/web-setup`), not
through a manually configured API credential -- GitHub requests never
receive one, even if configured. No token is ever visible inside the
session or written into this skill. The connected account/token needs
repo-creation and `administration:write` scope (for Step 4's branch
protection) -- check this before running the skill.

## Step 2 -- Pick the template and infer its answers from the spec

1. Read the actual `project-templates` repository directly (list its
   top-level directories; treat as a template only those with their own
   `cookiecutter.json`; skip any leading-underscore directory). Never
   assume a template exists from memory or convention.
2. Read that template's `cookiecutter.json` in full before asking anything.
3. For every variable except `project_slug` (which comes from the repo
   created in Step 1, never asked): read SPEC.md and infer the answer.
   - If SPEC.md explicitly calls for a capability (e.g. "needs structured
     logging"), turn the matching toggle on.
   - If SPEC.md is silent on a toggle, default it off.
   - State every inferred answer before rendering, e.g. "Plan doesn't
     mention logging -> defaulting structured logging off. Plan calls for
     app config -> turning app_config on." This keeps the inference visible
     even though it isn't asked as a question.
   - Only ask a genuine question when the spec is silent AND intent can't
     reasonably be inferred (e.g. a choice between architecturally
     different variants).

## Step 3 -- Render and push to main (still unprotected)

1. Clone the repo created in Step 1.
2. Write `cookiecutter-context.json` as `{"cookiecutter": {...}}` using the
   exact field names from Step 2's `cookiecutter.json`. Set `project_slug`
   (and `project_name` if used) to the repo's own name.
3. Run cookiecutter with `--output-dir` set to the repo's parent directory
   and `--overwrite-if-exists`, so it renders directly into the existing
   checkout rather than creating a new folder. Verify the rendered tree's
   slug matches the repo name -- stop on a mismatch.
4. Copy the approved spec into `spec/SPEC.md` and any ADRs into `spec/adrs/000N-*.md` within the rendered project.
5. `git add`, commit, and `git push` straight to `main`. This succeeds
   because `main` is still unprotected from Step 1.

## Step 4 -- Protect main (last step)

1. Now that real content is on `main`, turn on branch protection: require a
   PR before merging, require status checks, require at least one review.
2. From this point on, nothing lands on `main` without a reviewable diff --
   Issue generation and Execution (the next phases) rely on this.

## What this skill does NOT do

No issue decomposition, no application code, no ADR authoring (ADRs are
written during Plan, before this skill runs). Tell the human clearly when
Step 4 completes, so Issue generation can begin.