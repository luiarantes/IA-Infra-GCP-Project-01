# Golden Path Microservice Template (FastAPI + OpenTelemetry)

Template padronizado da plataforma de engenharia para criação acelerada de novos microsserviços com observabilidade, segurança e deployment Kubernetes integrados de fábrica.

---

## 🚀 Recursos Incluídos

* **FastAPI 0.111+**: Endpoints `/healthz`, `/readyz`, e `/api/v1/data` com validação assíncrona.
* **OpenTelemetry OTLP Integrado**: Instrumentação automática de traces e logs correlacionados com envio para o `otel-collector:4318`.
* **Métricas Prometheus**: Endpoint `/metrics` exposto e pronto para scraping do OpenTelemetry Collector.
* **Dockerfile Multi-Stage**: Imagem enxuta baseada em `python:3.12-slim` com usuário não-root (`appuser`).
* **Manifests Kubernetes Prontos**: `Deployment`, `Service` e `HorizontalPodAutoscaler` (HPA).
* **IDP Metadata (`catalog-info.yaml`)**: Compatível nativamente com **Spotify Backstage** e **Port**.

---

## 🛠️ Como Utilizar no IDP ou Localmente

1. Copie o diretório `templates/microservice-template/` para `apps/meu-novo-servico/`.
2. Substitua a variável `${SERVICE_NAME}` pelo nome do seu serviço.
3. Personalize a lógica de negócio em `app/main.py`.
4. O serviço será automaticamente catalogado pelo IDP e rastreado no OpenObserve!
