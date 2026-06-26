"""FastAPI wrapper for {{ cookiecutter.project_name }}."""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from agent import run_agent

app = FastAPI(title="{{ cookiecutter.project_name }}")


class RunRequest(BaseModel):
    message: str
    max_iterations: int = 10


class RunResponse(BaseModel):
    response: str


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/run", response_model=RunResponse)
async def run(req: RunRequest) -> RunResponse:
    try:
        result = run_agent(req.message, req.max_iterations)
        return RunResponse(response=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
