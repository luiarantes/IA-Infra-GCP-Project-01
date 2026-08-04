import json
import logging
import os
import threading

import requests
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-worker")

PROJECT_ID = os.environ["PROJECT_ID"]
PUBSUB_SUBSCRIPTION = os.environ.get("PUBSUB_SUBSCRIPTION", "microservices-queue-worker-pull")
SERVICE_DOWNSTREAM_URL = os.environ.get("SERVICE_DOWNSTREAM_URL", "http://service-downstream:8080")

app = FastAPI(title="service-worker")

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(PROJECT_ID, PUBSUB_SUBSCRIPTION)

# Sinaliza que o streaming pull ja foi iniciado - usado pelo /readyz,
# ja que o consumo roda numa thread de fundo gerenciada pela propria
# biblioteca google-cloud-pubsub, fora do loop de eventos do FastAPI.
_subscriber_started = threading.Event()


def handle_message(message: "pubsub_v1.subscriber.message.Message") -> None:
    try:
        body = json.loads(message.data.decode("utf-8"))
        request_id = body.get("request_id")
        logger.info("mensagem recebida: %s", request_id)

        response = requests.post(
            f"{SERVICE_DOWNSTREAM_URL}/process",
            json=body,
            timeout=5,
        )
        response.raise_for_status()
        logger.info("resultado do service-downstream para %s: %s", request_id, response.json())

        message.ack()
    except Exception:
        logger.exception("falha ao processar mensagem, nack para retry")
        message.nack()


@app.on_event("startup")
def start_subscriber():
    subscriber.subscribe(subscription_path, callback=handle_message)
    _subscriber_started.set()
    logger.info("subscriber iniciado em %s", subscription_path)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    if not _subscriber_started.is_set():
        return JSONResponse(content={"status": "not ready"}, status_code=503)
    return {"status": "ok"}
