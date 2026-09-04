import json
import logging
import os
import uuid

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from opentelemetry import propagate, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-api")

PROJECT_ID = os.environ.get("PROJECT_ID", "aiops-local")
PUBSUB_TOPIC = os.environ.get("PUBSUB_TOPIC", "microservices-queue")
PUBSUB_EMULATOR_HOST = os.environ.get("PUBSUB_EMULATOR_HOST")
OTEL_EXPORTER_OTLP_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
ENABLE_CLOUD_TRACE = os.environ.get("ENABLE_CLOUD_TRACE", "true").lower() == "true"

resource = Resource.create({"service.name": "service-api"})

# 1. Tracing OTel
provider = TracerProvider(resource=resource)

if OTEL_EXPORTER_OTLP_ENDPOINT:
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    headers = {}
    if os.environ.get("OTEL_EXPORTER_OTLP_HEADERS"):
        for h in os.environ["OTEL_EXPORTER_OTLP_HEADERS"].split(","):
            if "=" in h:
                k, v = h.split("=", 1)
                headers[k.strip()] = v.strip()
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT, headers=headers)))
    logger.info("Tracing OTel habilitado via OTLP: %s", OTEL_EXPORTER_OTLP_ENDPOINT)
elif ENABLE_CLOUD_TRACE and PROJECT_ID != "aiops-local":
    try:
        from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
        provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id=PROJECT_ID)))
        logger.info("Tracing OTel habilitado via CloudTraceSpanExporter (GCP)")
    except Exception as exc:
        logger.warning("Nao foi possivel inicializar CloudTraceSpanExporter: %s", exc)

trace.set_tracer_provider(provider)

# 2. Logging OTel
if OTEL_EXPORTER_OTLP_LOGS_ENDPOINT:
    try:
        from opentelemetry._logs import set_logger_provider
        from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
        from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
        from opentelemetry.sdk._logs.export import BatchLogRecordProcessor

        log_headers = {}
        if os.environ.get("OTEL_EXPORTER_OTLP_HEADERS"):
            for h in os.environ["OTEL_EXPORTER_OTLP_HEADERS"].split(","):
                if "=" in h:
                    k, v = h.split("=", 1)
                    log_headers[k.strip()] = v.strip()

        logger_provider = LoggerProvider(resource=resource)
        set_logger_provider(logger_provider)
        logger_provider.add_log_record_processor(
            BatchLogRecordProcessor(OTLPLogExporter(endpoint=OTEL_EXPORTER_OTLP_LOGS_ENDPOINT, headers=log_headers))
        )
        handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
        logging.getLogger().addHandler(handler)
        logger.info("Logging OTel habilitado via OTLP: %s", OTEL_EXPORTER_OTLP_LOGS_ENDPOINT)
    except Exception as exc:
        logger.warning("Nao foi possivel inicializar OTLPLogExporter: %s", exc)

app = FastAPI(title="service-api")
FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz")

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, PUBSUB_TOPIC)

# Se estiver em modo emulador, garante a existência do tópico no boot
if PUBSUB_EMULATOR_HOST:
    try:
        from google.api_core.exceptions import AlreadyExists
        publisher.create_topic(request={"name": topic_path})
        logger.info("Tópico criado no emulador Pub/Sub: %s", topic_path)
    except Exception as exc:
        logger.debug("Tópico já existente ou aguardando criação: %s", exc)


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

    # Injeta traceparent atual nos atributos da mensagem Pub/Sub
    carrier: dict[str, str] = {}
    propagate.inject(carrier)

    future = publisher.publish(topic_path, json.dumps(message).encode("utf-8"), **carrier)
    future.result(timeout=10)

    logger.info("mensagem publicada: %s", request_id)
    return JSONResponse(
        content={"status": "accepted", "request_id": request_id},
        status_code=202,
    )
