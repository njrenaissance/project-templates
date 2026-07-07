# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of [Cookiecutter](https://cookiecutter.readthedocs.io/) scaffolding templates. Currently one template exists:

- `basic` — minimal Python project (`src/` + `tests/`) using `uv`

## Commands

- Generate a project interactively: `cookiecutter https://github.com/njrenaissance/project-templates --directory basic` (or `cookiecutter ./basic` against a local checkout)
- Test-render a template with all defaults (no prompts), to validate changes before committing: `cookiecutter --no-input -o <output-dir> ./basic`
- After test-rendering, sanity-check the generated project actually works: `cd <output-dir>/<project_slug> && uv sync && uv run pytest && uv run ruff check . && uv run mypy src`

## Architecture

Each template directory follows the standard Cookiecutter layout:

- `cookiecutter.json` — the prompt schema: variable names, defaults, and choice lists (e.g. `basic/cookiecutter.json` defines `project_name`, a computed `project_slug` derived from it, `author`, and a `python_version` choice list).
- `{{cookiecutter.project_slug}}/` — the literal contents that become the generated project. **Every file under here is rendered as a Jinja2 template** (there's no `_copy_without_render` configured), including non-obvious ones like `pyproject.toml`, `CLAUDE.md`, and the GitHub Actions workflow files.

### Jinja/GitHub Actions delimiter collision

GitHub Actions expression syntax (`${{ ... }}`) and Jinja2's variable delimiters are the same (`{{ }}`). Because workflow files under `{{cookiecutter.project_slug}}/.github/workflows/` get rendered by Jinja, any *new* GitHub Actions expression added there (`${{ github.* }}`, `${{ secrets.* }}`, `${{ matrix.* }}`, etc.) must be wrapped in `{% raw %}...{% endraw %}`, otherwise Cookiecutter's render fails outright (e.g. `'github' is undefined`) rather than quietly producing a broken file. See `ci.yml`'s `concurrency.group` for a working example. Always test-render (`cookiecutter --no-input -o ...`) after touching a workflow file to catch this.

### Shared doc modules

Some docs (e.g. `GITWORKFLOW.md`) are authored once at the repo root as the canonical standard, then copied into each template's `{{cookiecutter.project_slug}}/docs/` folder and linked from that template's `CLAUDE.md` (rather than duplicated inline). This keeps a project's `CLAUDE.md` referencing a swappable module instead of hardcoding conventions that a given project might not need. When the root copy changes, re-sync it into each template that includes it.
