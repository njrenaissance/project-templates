# Changelog

All notable changes to the templates in this repository are documented here, per template. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## basic

### [1.2.0] - 2026-07-12

#### Added

- Full content for the six `.claude/standards/` documents stubbed in 1.1.0
  (`configuration.md`, `logging.md`, `telemetry.md`, `error-handling.md`,
  `security.md`, `testing.md`), each prescribing patterns and approved
  Python libraries for its concern (`pydantic-settings`, `structlog`,
  OpenTelemetry, `bandit`, `pytest-mock`). `configuration.md` covers nested
  per-concern `BaseSettings` sub-sections (with a `__`-delimited env var
  naming convention), JSON config files as an additional settings source,
  and centralizing non-secret defaults in a single dict for easy test
  overrides. `logging.md` treats `structlog` as required only when
  `structured_logging` is enabled, with `logging` module as the fallback.
- `pytest-mock` added to the `dev` dependency group (unconditional — the
  testing standard applies regardless of profile).
- `tests/conftest.py` with a `pytest_configure` hook that turns on live
  `INFO`-level log output automatically when running `pytest -v`.

#### Changed

- `.claude/standards/` documents are no longer wired to a `CLAUDE.md`
  section that doesn't exist yet (the earlier stub-era draft referenced
  scaffold-time profile checks in `CLAUDE.md`; that wiring is still a
  follow-up, not yet in this template).

### [1.1.0] - 2026-07-12

#### Added

- `app_config`, `structured_logging`, `telemetry`, and `security` (`no`/`yes`) cookiecutter prompts; `pyproject.toml` now conditionally includes `pydantic-settings`/`python-dotenv` (app_config), `structlog` (structured_logging), `opentelemetry-sdk`/`opentelemetry-api` (telemetry), and `bandit` (security) based on the selections — each prompt is independent, with no forced bundling.
- `.claude/standards/` directory alongside `.claude/rules/` for cross-cutting, non-file-type-specific agent guidance — stubbed with `configuration.md`, `logging.md`, `telemetry.md`, `error-handling.md`, `security.md`, `testing.md` (full content is a follow-up issue).

#### Changed

- Moved `docs/GITWORKFLOW.md` to `.claude/standards/git-workflow.md` and updated `CLAUDE.md`'s `@` import path accordingly.

#### Removed

- The `docs/` folder (empty after the `GITWORKFLOW.md` move) and the now-dead `docs/**` entry in `ci.yml`'s `paths-ignore`.

### [1.0.0] - 2026-07-07

#### Added

- Initial `basic` template: minimal Python project (`src/` + `tests/`) using `uv`.
- CI pipeline (`ci.yml`) composed of reusable `format-lint.yml`, `type-check.yml`, `unit-tests.yml` workflows, with pinned action SHAs, `timeout-minutes`, and PR concurrency cancellation.
- `.github/dependabot.yml` to keep pinned GitHub Actions SHAs updated.
- Modular git workflow docs (`docs/GITWORKFLOW.md`) imported into `CLAUDE.md` via Claude Code's `@` import syntax.
- `.cookiecutter-template-version` to track which template version a generated project was scaffolded from.
