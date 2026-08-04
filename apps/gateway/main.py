import logging
import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gateway")

SERVICE_API_URL = os.environ.get("SERVICE_API_URL", "http://service-api:8080")

app = FastAPI(title="gateway")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/work")
async def work(payload: dict | None = None):
    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.post(f"{SERVICE_API_URL}/work", json=payload or {})
        except httpx.HTTPError as exc:
            logger.error("falha ao chamar service-api: %s", exc)
            raise HTTPException(status_code=502, detail="service-api indisponivel") from exc

    return JSONResponse(content=response.json(), status_code=response.status_code)
