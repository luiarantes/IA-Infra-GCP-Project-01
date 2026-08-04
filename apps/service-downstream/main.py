import logging
import os
import random
import time

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-downstream")

PROJECT_ID = os.environ["PROJECT_ID"]

provider = TracerProvider(resource=Resource.create({"service.name": "service-downstream"}))
provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id=PROJECT_ID)))
trace.set_tracer_provider(provider)

app = FastAPI(title="service-downstream")
FastAPIInstrumentor.instrument_app(app)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/process")
def process(payload: dict):
    # Simula uma dependencia externa lenta - so pra ter algo real pra
    # tracing/latencia medirem.
    time.sleep(random.uniform(0.05, 0.3))

    request_id = payload.get("request_id")
    logger.info("processado: %s", request_id)
    return {
        "result": "processed",
        "request_id": request_id,
        "echo": payload.get("payload"),
    }
