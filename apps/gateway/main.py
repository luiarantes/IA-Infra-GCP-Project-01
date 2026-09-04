import logging
import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gateway")

SERVICE_API_URL = os.environ.get("SERVICE_API_URL", "http://service-api:8080")
PROJECT_ID = os.environ.get("PROJECT_ID", "aiops-local")
OTEL_EXPORTER_OTLP_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_LOGS_ENDPOINT")
ENABLE_CLOUD_TRACE = os.environ.get("ENABLE_CLOUD_TRACE", "true").lower() == "true"

resource = Resource.create({"service.name": "gateway"})

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

HTTPXClientInstrumentor().instrument()

app = FastAPI(title="gateway")
FastAPIInstrumentor.instrument_app(app, excluded_urls="healthz,readyz")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ok"}


@app.post("/work")
async def work(payload: dict | None = None):
    span = trace.get_current_span()
    trace_id = format(span.get_span_context().trace_id, "032x")

    async with httpx.AsyncClient(timeout=5.0) as client:
        try:
            response = await client.post(f"{SERVICE_API_URL}/work", json=payload or {})
        except httpx.HTTPError as exc:
            logger.error("falha ao chamar service-api: %s", exc)
            raise HTTPException(status_code=502, detail="service-api indisponivel") from exc

    body = response.json()
    logger.info("trace_id=%s request_id=%s", trace_id, body.get("request_id"))

    return JSONResponse(content=body, status_code=response.status_code)
