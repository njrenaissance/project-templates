from mcp.server.fastmcp import FastMCP

mcp = FastMCP("{{ cookiecutter.project_name }}")


@mcp.tool()
def hello(name: str) -> str:
    """Say hello — replace with your real tool."""
    return f"Hello, {name}!"


if __name__ == "__main__":
    mcp.run(transport="{{ cookiecutter.transport[0] }}")
