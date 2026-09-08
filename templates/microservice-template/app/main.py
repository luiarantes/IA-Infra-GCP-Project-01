import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Response, status
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from prometheus_fastapi_instrumentator import Instrumentator

SERVICE_NAME = os.getenv("SERVICE_NAME", "sample-microservice")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318/v1/traces")

# Configurar OpenTelemetry Tracing
resource = Resource.create({"service.name": SERVICE_NAME})
provider = TracerProvider(resource=resource)
if OTEL_ENDPOINT:
    processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT))
    provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(SERVICE_NAME)

# Configurar Logging Estruturado
logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s", "level":"%(levelname)s", "service":"%(name)s", "message":"%(message)s"}'
)
logger = logging.getLogger(SERVICE_NAME)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Iniciando servico {SERVICE_NAME}...")
    yield
    logger.info(f"Finalizando servico {SERVICE_NAME}...")


app = FastAPI(title=SERVICE_NAME, lifespan=lifespan)

# Instrumentar métricas Prometheus em /metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# Instrumentar tracing automático excluindo probes
FastAPIInstrumentor.instrument_app(
    app,
    tracer_provider=provider,
    excluded_urls="healthz,readyz,metrics"
)


@app.get("/healthz", status_code=status.HTTP_200_OK)
async def healthz():
    return {"status": "ok", "service": SERVICE_NAME}


@app.get("/readyz", status_code=status.HTTP_200_OK)
async def readyz():
    return {"status": "ready", "service": SERVICE_NAME}


@app.get("/api/v1/data")
async def get_data():
    with tracer.start_as_current_span("process_data_operation"):
        logger.info("Processando requisicao na rota /api/v1/data")
        return {
            "message": "Dados processados com sucesso!",
            "service": SERVICE_NAME,
            "version": "1.0.0"
        }
