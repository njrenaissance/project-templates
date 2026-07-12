# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of [Cookiecutter](https://cookiecutter.readthedocs.io/) scaffolding templates. Currently one template exists:

- `basic` — minimal Python project (`src/` + `tests/`) using `uv`

**Design principle**: each template bakes in as much as possible as deterministic, machine-enforced config — pinned CI, dependabot, lint/type-check/test commands, `.cookiecutter-template-version` — so it's enforced consistently without relying on an agent to remember it. Anything that isn't reducible to a fixed rule (coding conventions, when to branch, how docs relate to each other) goes in that generated project's own `CLAUDE.md` and its imports/rules instead, where an agent can apply judgment. When adding to a template, prefer config over a `CLAUDE.md` instruction wherever a machine can actually enforce the rule.

## Commands

- Generate a project interactively: `cookiecutter https://github.com/njrenaissance/project-templates --directory basic` (or `cookiecutter ./basic` against a local checkout)
- Test-render a template with all defaults (no prompts), to validate changes before committing: `cookiecutter --no-input -o <output-dir> ./basic`
- After test-rendering, sanity-check the generated project actually works: `cd <output-dir>/<project_slug> && uv sync && uv run pytest && uv run ruff check . && uv run mypy src`

## Architecture

Each template directory follows the standard Cookiecutter layout:

- `cookiecutter.json` — the prompt schema: variable names, defaults, and choice lists (e.g. `basic/cookiecutter.json` defines `project_name`, a computed `project_slug` derived from it, `author`, and a `python_version` choice list).
- `{{cookiecutter.project_slug}}/` — the literal contents that become the generated project. **Every file under here is rendered as a Jinja2 template** (there's no `_copy_without_render` configured), including non-obvious ones like `pyproject.toml`, `CLAUDE.md`, and the GitHub Actions workflow files.
- `{{cookiecutter.project_slug}}/.cookiecutter-template-version` — a static, hand-maintained semver (e.g. `1.0.0`) recording which version of the template a generated project was scaffolded from. It's a bare single-line value like `.nvmrc`/`.python-version`, not something cookiecutter prompts for — bump it by hand in the template source whenever you make a meaningful change to that template, and log the change in `CHANGELOG.md`.

### Jinja/GitHub Actions delimiter collision

GitHub Actions expression syntax (`${{ ... }}`) and Jinja2's variable delimiters are the same (`{{ }}`). Because workflow files under `{{cookiecutter.project_slug}}/.github/workflows/` get rendered by Jinja, any *new* GitHub Actions expression added there (`${{ github.* }}`, `${{ secrets.* }}`, `${{ matrix.* }}`, etc.) must be wrapped in `{% raw %}...{% endraw %}`, otherwise Cookiecutter's render fails outright (e.g. `'github' is undefined`) rather than quietly producing a broken file. See `ci.yml`'s `concurrency.group` for a working example. Always test-render (`cookiecutter --no-input -o ...`) after touching a workflow file to catch this.

### Shared doc modules

Docs like `GITWORKFLOW.md` live under each template's own `{{cookiecutter.project_slug}}/.claude/standards/` folder (cross-cutting guidance, alongside the tool/language-specific `{{cookiecutter.project_slug}}/.claude/rules/`) and get linked from that template's `CLAUDE.md` via Claude Code's `@` import syntax (rather than duplicated inline into `CLAUDE.md` itself). This keeps a project's `CLAUDE.md` referencing a swappable module instead of hardcoding conventions that a given project might not need. If a second template ends up needing the same doc, promote it back to a root-level canonical copy (this repo tried that once — see git history — and dropped it while there was only one template) and keep each template's copy in sync with it, e.g. via a CI check that diffs them.

### CHANGELOG.md

`CHANGELOG.md` at the repo root tracks notable changes *to the templates themselves* (one section per template, e.g. `## basic`), not changes to any project generated from them — a generated project's own history lives in its git log and its own changelog, if it has one. Bump a template's `.cookiecutter-template-version` and add an entry here whenever you make a meaningful change to that template.
