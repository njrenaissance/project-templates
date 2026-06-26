# {{ cookiecutter.project_name }}

Generated from the `agent` cookiecutter template.
A Claude agent with tool use, served via FastAPI.

## Structure

```
├── agent.py      # Agent loop (model calls, tool dispatch)
├── tools.py      # Tool definitions + handlers
├── main.py       # FastAPI wrapper
└── requirements.txt
```

## Setup

```bash
pip install -r requirements.txt
cp .env.example .env
# Add your ANTHROPIC_API_KEY to .env
```

## Run

```bash
uvicorn main:app --reload --port {{ cookiecutter.port }}
```

Then POST to `/run`:

```bash
curl -X POST http://localhost:{{ cookiecutter.port }}/run \
  -H 'Content-Type: application/json' \
  -d '{"message": "What time is it?"}'
```

## Add a tool

1. Add the JSON Schema definition to `TOOLS` in `tools.py`
2. Add a handler branch in `handle_tool_call`
3. That's it — the agent loop in `agent.py` picks it up automatically
