import logging
import os
import random
import time

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("service-downstream")

PROJECT_ID = os.environ.get("PROJECT_ID", "aiops-local")
OTEL_EXPORTER_OTLP_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
ENABLE_CLOUD_TRACE = os.environ.get("ENABLE_CLOUD_TRACE", "true").lower() == "true"

resource = Resource.create({"service.name": "service-downstream"})

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

# 3. Continuous Profiling (Pyroscope)
PYROSCOPE_SERVER_ADDRESS = os.environ.get("PYROSCOPE_SERVER_ADDRESS")
if PYROSCOPE_SERVER_ADDRESS:
    try:
        import pyroscope

        pyroscope.configure(
            application_name="service-downstream",
            server_address=PYROSCOPE_SERVER_ADDRESS,
            tags={"service_name": "service-downstream"},
        )
        logger.info("Pyroscope continuous profiling habilitado: %s", PYROSCOPE_SERVER_ADDRESS)
    except Exception as exc:
        logger.warning("Nao foi possivel inicializar Pyroscope: %s", exc)

app = FastAPI(title="service-downstream")
FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/process")
def process(payload: dict):
    # Simula uma dependencia externa com variacao de latencia
    time.sleep(random.uniform(0.05, 0.3))

    request_id = payload.get("request_id")
    logger.info("processado: %s", request_id)
    return {
        "result": "processed",
        "request_id": request_id,
        "echo": payload.get("payload"),
    }
