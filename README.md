# project-templates

Cookiecutter scaffolding templates. Use with the `/scaffold-project` Claude Code command.

## Templates

| Directory | Description |
|-----------|-------------|
| `fastapi` | FastAPI service with health endpoint |
| `mcp-server` | MCP server using FastMCP |
| `azure-container-app` | FastAPI app with Dockerfile + GitHub Actions deploy |

## Usage

```bash
cookiecutter https://github.com/njrenaissance/project-templates --directory <template>
```

Or via Claude Code:

```
/scaffold-project fastapi
/scaffold-project mcp-server
/scaffold-project azure-container-app
```
