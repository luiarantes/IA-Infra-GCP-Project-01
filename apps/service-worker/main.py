import json
import logging
import os
import threading
import time

import requests
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from opentelemetry import propagate, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-worker")

PROJECT_ID = os.environ.get("PROJECT_ID", "aiops-local")
PUBSUB_TOPIC = os.environ.get("PUBSUB_TOPIC", "microservices-queue")
PUBSUB_SUBSCRIPTION = os.environ.get("PUBSUB_SUBSCRIPTION", "microservices-queue-worker-pull")
PUBSUB_EMULATOR_HOST = os.environ.get("PUBSUB_EMULATOR_HOST")
SERVICE_DOWNSTREAM_URL = os.environ.get("SERVICE_DOWNSTREAM_URL", "http://service-downstream:8080")
OTEL_EXPORTER_OTLP_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
ENABLE_CLOUD_TRACE = os.environ.get("ENABLE_CLOUD_TRACE", "true").lower() == "true"

resource = Resource.create({"service.name": "service-worker"})

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
tracer = trace.get_tracer(__name__)

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

RequestsInstrumentor().instrument()

app = FastAPI(title="service-worker")
FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz")

_subscriber_started = threading.Event()


def handle_message(message: "pubsub_v1.subscriber.message.Message") -> None:
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


def _iniciar_subscriber():
    from google.api_core.exceptions import AlreadyExists

    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(PROJECT_ID, PUBSUB_SUBSCRIPTION)

    if PUBSUB_EMULATOR_HOST:
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(PROJECT_ID, PUBSUB_TOPIC)
        for tentativa in range(1, 15):
            try:
                try:
                    publisher.create_topic(request={"name": topic_path})
                except AlreadyExists:
                    pass
                try:
                    subscriber.create_subscription(request={"name": subscription_path, "topic": topic_path})
                except AlreadyExists:
                    pass
                break
            except Exception as exc:
                logger.warning("Tentativa %d/15 conectando ao emulador Pub/Sub: %s", tentativa, exc)
                time.sleep(2)

    subscriber.subscribe(subscription_path, callback=handle_message)
    _subscriber_started.set()
    logger.info("subscriber iniciado em %s", subscription_path)


@app.on_event("startup")
def startup_event():
    threading.Thread(target=_iniciar_subscriber, daemon=True).start()


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    if not _subscriber_started.is_set():
        return JSONResponse(content={"status": "not ready"}, status_code=503)
    return {"status": "ok"}
