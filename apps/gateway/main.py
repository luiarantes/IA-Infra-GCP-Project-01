import logging
import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gateway")

SERVICE_API_URL = os.environ.get("SERVICE_API_URL", "http://service-api:8080")
PROJECT_ID = os.environ["PROJECT_ID"]

# Exporta spans reais para o Cloud Trace - usa a KSA microservices-trace-ksa
# (Workload Identity, GSA so com roles/cloudtrace.agent) para autenticar
# sem credencial estatica - ver apps/shared/serviceaccount.yaml.
provider = TracerProvider(resource=Resource.create({"service.name": "gateway"}))
provider.add_span_processor(BatchSpanProcessor(CloudTraceSpanExporter(project_id=PROJECT_ID)))
trace.set_tracer_provider(provider)

HTTPXClientInstrumentor().instrument()

app = FastAPI(title="gateway")
FastAPIInstrumentor.instrument_app(app)


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
