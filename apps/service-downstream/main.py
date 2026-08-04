import logging
import random
import time

from fastapi import FastAPI

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-downstream")

app = FastAPI(title="service-downstream")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/process")
def process(payload: dict):
    # Simula uma dependencia externa lenta - so pra ter algo real pra
    # tracing/latencia medirem nas proximas sub-fases.
    time.sleep(random.uniform(0.05, 0.3))

    request_id = payload.get("request_id")
    logger.info("processado: %s", request_id)
    return {
        "result": "processed",
        "request_id": request_id,
        "echo": payload.get("payload"),
    }
