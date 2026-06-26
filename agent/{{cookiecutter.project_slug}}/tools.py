"""Tool definitions and handlers for {{ cookiecutter.project_name }}."""

# Add your tool definitions here.
# Each tool needs a JSON Schema definition (for the API) and a handler function.

TOOLS = [
    {
        "name": "get_current_time",
        "description": "Returns the current UTC time. Replace with your real tools.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    }
]


def handle_tool_call(name: str, inputs: dict):
    """Dispatch tool calls to their handlers."""
    if name == "get_current_time":
        from datetime import datetime, timezone
        return {"time": datetime.now(timezone.utc).isoformat()}

    raise ValueError(f"Unknown tool: {name}")
