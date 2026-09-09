# Ambiente Local (Kind + Terraform)

Este diretório contém a estrutura de Infraestrutura como Código (Terraform) para provisionar o ambiente Kubernetes local utilizando o provider **`tehcyx/kind`** e provisionamento declarativo de workloads locais.

---

## 🏗️ Arquitetura do Ambiente Local

```
  Ambiente Local (Docker)
  ├── Cluster Kind (aiops-local)
  │   └── Control-Plane Node (NodePorts mapeados para localhost)
  │       ├── Gateway (localhost:8080 -> Port 30080)
  │       ├── BuscaCEP Web/API (localhost:8000 -> Port 30000)
  │       ├── OpenObserve (localhost:5080 -> Port 30580)
  │       └── Pub/Sub Emulator (localhost:8085 -> Port 30085)
  ├── In-Cluster Workloads:
  │   ├── Metrics-Server (Métricas de CPU/Memória para HPA)
  │   ├── OpenTelemetry Collector (OTLP 4317/4318 + Scrape Prometheus)
  │   ├── Microsserviços (Gateway, Service-API, Service-Worker, Service-Downstream)
  │   └── Aplicação BuscaCEP (API + Worker)
```

---

## 🚀 Como Executar

### Via Makefile (Recomendado)
```bash
# Provisiona o cluster e todas as cargas de trabalho
make local-up

# Testa os endpoints
make local-test

# Destrói o cluster liberando recursos (custo zero)
make local-down
```

### Via Terraform CLI
```bash
cd infra/environments/local
terraform init
terraform apply -auto-approve
```

---

## 📊 Endpoints Locais

| Serviço | URL Local | Descrição |
|---|---|---|
| **Gateway da Infra** | `http://localhost:8080` | Ponto de entrada da malha de microsserviços |
| **BuscaCEP Web & API** | `http://localhost:8000` | Frontend web e API de consulta de CEPs |
| **OpenObserve** | `http://localhost:5080` | UI de logs, traces e métricas (`admin@example.com` / `ComplexPassword123#`) |
| **Pub/Sub Emulator** | `http://localhost:8085` | Emulador local do Google Cloud Pub/Sub |
