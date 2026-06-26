# {{ cookiecutter.project_name }}

Generated from the `mcp-server` cookiecutter template.

## Run

```bash
pip install -r requirements.txt
python server.py
```

## Register with Claude Code

Add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "{{ cookiecutter.project_slug }}": {
      "command": "python",
      "args": ["path/to/server.py"]
    }
  }
}
```
