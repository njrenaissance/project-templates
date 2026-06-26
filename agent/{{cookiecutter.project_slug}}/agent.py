"""Core agent loop for {{ cookiecutter.project_name }}."""
import json
import anthropic
from tools import TOOLS, handle_tool_call

client = anthropic.Anthropic()

SYSTEM_PROMPT = """
You are a helpful assistant. Replace this with your agent's persona and instructions.
"""


def run_agent(user_message: str, max_iterations: int = 10) -> str:
    """Run the agent loop and return the final text response."""
    messages = [{"role": "user", "content": user_message}]

    for _ in range(max_iterations):
        response = client.messages.create(
            model="{{ cookiecutter.model }}",
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        # Append assistant response
        messages.append({"role": "assistant", "content": response.content})

        if response.stop_reason == "end_turn":
            # Extract final text
            for block in response.content:
                if hasattr(block, "text"):
                    return block.text
            return ""

        if response.stop_reason == "tool_use":
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    result = handle_tool_call(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                    })
            messages.append({"role": "user", "content": tool_results})

    return "Max iterations reached."
