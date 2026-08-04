import json
import logging
import os
import threading

import requests
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from opentelemetry import propagate, trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-worker")

PROJECT_ID = os.environ["PROJECT_ID"]
PUBSUB_SUBSCRIPTION = os.environ.get("PUBSUB_SUBSCRIPTION", "microservices-queue-worker-pull")
SERVICE_DOWNSTREAM_URL = os.environ.get("SERVICE_DOWNSTREAM_URL", "http://service-downstream:8080")

provider = TracerProvider(resource=Resource.create({"service.name": "service-worker"}))
provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id=PROJECT_ID)))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

# Instrumenta o cliente `requests` globalmente - a chamada pro
# service-downstream dentro do callback do subscriber (mais abaixo) sai
# com o traceparent do span atual injetado automaticamente no header.
RequestsInstrumentor().instrument()

app = FastAPI(title="service-worker")
FastAPIInstrumentor.instrument_app(app)

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(PROJECT_ID, PUBSUB_SUBSCRIPTION)

_subscriber_started = threading.Event()


def handle_message(message: "pubsub_v1.subscriber.message.Message") -> None:
    # Recupera o trace iniciado no gateway/service-api a partir dos
    # atributos da mensagem - sem isso, cada mensagem viraria um trace
    # novo e desconectado no Cloud Trace.
    carrier = dict(message.attributes)
    ctx = propagate.extract(carrier)

    with tracer.start_as_current_span("service-worker.process_message", context=ctx):
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
