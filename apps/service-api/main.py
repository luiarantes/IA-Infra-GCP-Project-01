import json
import logging
import os
import uuid

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-api")

PROJECT_ID = os.environ["PROJECT_ID"]
PUBSUB_TOPIC = os.environ.get("PUBSUB_TOPIC", "microservices-queue")

app = FastAPI(title="service-api")
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, PUBSUB_TOPIC)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/work")
def work(payload: dict | None = None):
    request_id = str(uuid.uuid4())
    message = {"request_id": request_id, "payload": payload or {}}

    future = publisher.publish(topic_path, json.dumps(message).encode("utf-8"))
    future.result(timeout=10)

    logger.info("mensagem publicada: %s", request_id)
    return JSONResponse(
        content={"status": "accepted", "request_id": request_id},
        status_code=202,
    )
