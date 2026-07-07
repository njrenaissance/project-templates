# {{ cookiecutter.project_name }}

Minimal Python project managed with [uv](https://docs.astral.sh/uv/).

## Structure

```text
├── src/
│   └── main.py       # greet()
├── tests/
│   └── test_main.py  # test for greet()
└── pyproject.toml
```

## Commands

```bash
uv sync                    # install dependencies
uv run python src/main.py  # run
uv run pytest              # test
uv run ruff check .        # lint
uv run ruff format .       # format
uv run mypy src            # type-check
```

## Conventions

All code must follow Clean Code principles (Robert C. Martin) — no exceptions.

Where applicable, apply the 23 Gang of Four design patterns (*Design Patterns: Elements of Reusable Object-Oriented Software*) rather than ad-hoc structures:

- **Creational**: Abstract Factory, Builder, Factory Method, Prototype, Singleton
- **Structural**: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy
- **Behavioral**: Chain of Responsibility, Command, Interpreter, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

Don't force a pattern where a plain function or class is simpler — use these to name and structure a design once the problem actually calls for one.

Python- and test-specific conventions live in `.claude/rules/` (`python-lang.md`, `pytest-rules.md`) and load automatically when Claude touches matching files.

Run `uv run pytest`, `uv run ruff check .`, and `uv run mypy src` before considering a change done.

## Git workflow

`main` is the golden source of truth — it is always releasable and always green.

- Never commit or push directly to `main`. All work happens on a branch (`feature/...`, `fix/...`) and lands via a pull request.
- Never rewrite `main` history — no force-push, no `reset --hard`, no amending commits that are already on `main`.
- Every PR must pass `ci.yml` (lint, type-check, unit-tests — see `.github/workflows/`) before merging. Don't bypass required checks.
- Keep branches short-lived and scoped to one change; rebase/update from `main` rather than letting a branch drift far behind it.
- If you need to fix something already merged to `main`, open a new branch and PR rather than editing `main` directly, even for "small" fixes.
