import json
import logging
import os
import uuid

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from opentelemetry import propagate, trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-api")

PROJECT_ID = os.environ["PROJECT_ID"]
PUBSUB_TOPIC = os.environ.get("PUBSUB_TOPIC", "microservices-queue")

provider = TracerProvider(resource=Resource.create({"service.name": "service-api"}))
provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id=PROJECT_ID)))
trace.set_tracer_provider(provider)

app = FastAPI(title="service-api")
FastAPIInstrumentor.instrument_app(app)

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

    # Pub/Sub nao propaga trace context sozinho como HTTP faz (o
    # FastAPIInstrumentor cuida disso automaticamente pra chamadas
    # HTTP) - injeta o traceparent atual como atributos da mensagem,
    # pro service-worker recuperar do outro lado da fila.
    carrier: dict[str, str] = {}
    propagate.inject(carrier)

    future = publisher.publish(topic_path, json.dumps(message).encode("utf-8"), **carrier)
    future.result(timeout=10)

    logger.info("mensagem publicada: %s", request_id)
    return JSONResponse(
        content={"status": "accepted", "request_id": request_id},
        status_code=202,
    )
