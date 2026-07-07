# Changelog

All notable changes to the templates in this repository are documented here, per template. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## basic

### [1.0.0] - 2026-07-07

#### Added

- Initial `basic` template: minimal Python project (`src/` + `tests/`) using `uv`.
- CI pipeline (`ci.yml`) composed of reusable `format-lint.yml`, `type-check.yml`, `unit-tests.yml` workflows, with pinned action SHAs, `timeout-minutes`, and PR concurrency cancellation.
- `.github/dependabot.yml` to keep pinned GitHub Actions SHAs updated.
- Modular git workflow docs (`docs/GITWORKFLOW.md`) imported into `CLAUDE.md` via Claude Code's `@` import syntax.
- `.cookiecutter-template-version` to track which template version a generated project was scaffolded from.
