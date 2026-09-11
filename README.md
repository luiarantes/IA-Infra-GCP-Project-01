# AIOps Platform — Multi-Target IaC, Observability & Self-Healing

Plataforma Kubernetes efêmera, declarativa e multi-nuvem (**Local Kind**, **GCP GKE Standard SPOT** e **AWS EKS [Em Desenvolvimento]**), provisionada inteiramente por código (**Terraform**) com observabilidade 100% agnóstica (**OpenTelemetry + OpenObserve**) e agentes de IA que detectam incidentes, investigam a causa raiz e abrem Pull Requests de correção — sempre com aprovação humana obrigatória.

---

## 🏗️ Arquitetura Multi-Target

```
                     [ TERRAFORM IAC UNIFICADO ]
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
  [ AMBIENTE LOCAL ]       [ AMBIENTE GCP ]         [ AMBIENTE AWS ]
  • Kind (Docker)          • GKE Spot               • EKS Spot (Scaffold)
  • Custo: R$ 0,00         • Custo: ~R$ 0,08/h      • Em Desenvolvimento
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  ▼
              [ CAMADA DE APLICAÇÃO 100% AGNÓSTICA ]
              • Microsserviços FastAPI (OTLP HTTP / 4318)
              • OpenTelemetry Collector Gateway (Two-Tier)
              • OpenObserve + Grafana Labs (Tempo, Loki)
              • In-Cluster AIOps Agent Runner (SQL Parquet)
```

| Componente | 🟢 Ambiente Local (Kind) | 🟢 Ambiente Nuvem GCP | 🟡 Ambiente Nuvem AWS |
| :--- | :--- | :--- | :--- |
| **Status** | **100% Operacional** (Offline) | **100% Operacional** (Efêmero CI/CD) | **Em Desenvolvimento / Scaffold** |
| **Diretório IaC** | `infra/environments/local/` | `infra/environments/test/` | `infra/environments/aws/` |
| **Provider** | `tehcyx/kind` | `hashicorp/google` | `hashicorp/aws` |
| **Cluster K8s** | Kind em Docker | GKE Standard Zonal (Spot) | Alvo: AWS EKS (Spot) |
| **Mensageria** | Pub/Sub Emulator | Google Cloud Pub/Sub | Alvo: Amazon SQS/SNS |
| **Observabilidade** | OpenObserve + Grafana Labs | OpenObserve + Grafana Labs | Alvo: OpenObserve + Grafana Labs |
| **Custo Estimado** | **R$ 0,00** | **~R$ 0,08/h** | *Roadmap: Próxima Fase* |



---

## 🔄 Fluxo de Microsserviços & Telemetria

```
[ Cliente / k6 ]
       │ (HTTP POST /work)
       ▼
[ Gateway ] ──────────┐
       │              │
       ▼              │
 [ Service-API ]      │ (Telemetria OTLP HTTP / 4318)
       │              │
  (Pub/Sub Topic)     ▼
       │      [ OpenTelemetry Collector ]
       ▼              │ (Exportação OTLP)
[ Service-Worker ]    ▼
       │      [ OpenObserve Engine ]
       ▼      (Parquet + Apache DataFusion SQL)
[ Service-Downstream ]
```

---

## 📊 Stack de Observabilidade Dual-Engine & Modos de Operação

A plataforma opera com **duas stacks completas de observabilidade** alimentadas simultaneamente por um pipeline de **Fan-Out via OpenTelemetry Collector**:
1. **OpenObserve**: Motor colunar ultrarrápido (Apache Parquet + Apache DataFusion SQL).
2. **Grafana Labs In-Cluster**: Suíte analítica corporativa com **Grafana OSS**, **Tempo** (traces), **Loki** (logs), **Pyroscope** (continuous profiling) e **Beyla** (auto-instrumentação eBPF no kernel Linux).

👉 **Guia Detalhado da Stack:** [Consulte a documentação completa em `observability/README.md`](observability/README.md).

### Por que existem dois modos de implantação? (`simple` vs `distributed`)

| Critério | Modo `simple` (Monolítico Leve) | Modo `distributed` (Arquitetura de Produção) |
| :--- | :--- | :--- |
| **Objetivo** | **Estudo local e desenvolvimento rápido** | **Simulação de ambiente produtivo corporativo** |
| **Armazenamento** | Filesystem local no container / PVC | **Object Storage Desacoplado** (Google GCS ou MinIO S3) |
| **Separação CQRS**| Leitura e escrita competem no mesmo pod | **Isolamento total**: Queriers escalam sem afetar Ingestão |
| **Resiliência FinOps**| Depende de anexar/desanexar discos | **100% Stateless**: nós Spot podem morrer sem perda de dados |
| **Custo na Nuvem** | Discos persistentes caros (~US$ 0,17/GB) | **Object Storage ~10x mais barato (~US$ 0,02/GB)** |
| **Requisitos Docker**| **8 GB RAM / 4 vCPUs** | **12 GB RAM / 6 vCPUs** |

> **Como alternar:** O modo é selecionado de forma declarativa via variável `grafana_stack_mode` no Terraform do GCP (`infra/environments/test/`) e no Terraform Local (`infra/environments/local/`).

---

## 🚀 Como Executar

### Opção 1: Ambiente Local (Kind + Terraform) — 100% Gratuito & Offline

Não exige conta em nuvem nem cartões de crédito.

```bash
# Provisiona o cluster Kind local via Terraform e sobe todos os serviços
make local-up
```

* **Gateway de Entrada**: `http://localhost:8080`
* **BuscaCEP Web & API**: `http://localhost:8000`
* **Grafana OSS (Dashboards, Tempo, Loki)**: `http://localhost:3000` *(Login: `admin` / `admin`)*
* **Grafana Pyroscope (Continuous Profiling)**: `http://localhost:4040`
* **OpenObserve Web UI**: `http://localhost:5080` *(Login: `admin@example.com` / `ComplexPassword123#`)*
* **Pub/Sub Emulator**: `http://localhost:8085`


```bash
# Envia requisições de teste
make local-test

# Inicia gerador contínuo de tráfego em background (~2 req/s)
make local-traffic-start

# Executa agente de IA localmente
make local-agent

# Destrói o ambiente local liberando recursos (custo zero)
make local-down
```

---

### Opção 2: Ambiente Nuvem GCP (GKE Standard Zonal SPOT)

Provisionado de forma efêmera via GitHub Actions com custo otimizado (~R$ 0,08/hora).

1. **Bootstrap inicial (uma única vez)**:
   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply -var="project_id=SEU_PROJECT_ID" -var="state_bucket_name=SEU_TFSTATE_BUCKET" -var="github_org=SEU_USER" -var="github_repo=SEU_REPO"
   ```
2. **Provisionar Infraestrutura (GKE Spot + VPC + Pub/Sub)**:
   ```bash
   make gcp-up
   # ou: gh workflow run terraform-apply.yml
   ```
3. **Implantar Observabilidade & Microsserviços**:
   ```bash
   gh workflow run deploy-observability.yml
   gh workflow run deploy-microservices.yml
   ```
4. **Destruir o Ambiente em Nuvem ao Final da Sessão**:
   ```bash
   make gcp-down
   # ou: gh workflow run terraform-destroy.yml -f confirm="destroy"
   ```

---

## 🤖 Agentes de Self-Healing (AIOps)

O ciclo de auto-recuperação opera de forma determinística e com aprovação humana obrigatória:

```
Incidente detectado (crash, erro 5xx, latência, CPU/memória)
  → Agente Log-Analyzer investiga via SQL no OpenObserve e abre uma GitHub Issue
  → Agente PR-Creator analisa a issue e abre um Pull Request com a correção
  → Humano revisa e aprova o merge do PR
  → Deploy automatizado aplica o fix
  → Agente Verify-Fix reconsulta a métrica no OpenObserve e valida a estabilização
```

---

## 📦 Estrutura do Repositório

```
repo/
├── infra/
│   ├── bootstrap/          # WIF + State Bucket remoto
│   ├── modules/            # gke (Zonal Spot), network, pubsub, artifact-registry
│   └── environments/
│       ├── local/          # Terraform para Kind local
│       ├── test/           # Terraform para GCP GKE Spot
│       └── aws/            # [Em Desenvolvimento] Scaffold Terraform para AWS EKS
├── apps/
│   ├── gateway/            # Ponto de entrada HTTP
│   ├── service-api/        # Producer Pub/Sub
│   ├── service-worker/     # Consumer assíncrono
│   ├── service-downstream/ # Processamento downstream
│   └── sample-app/         # Podinfo com injeção de falhas
├── observability/          # OpenObserve, OTel Collector e Traffic Generator
├── templates/
│   └── microservice-template/ # Template scaffold para novos microsserviços
├── agents/                 # Log Analyzer, PR Creator, Verify Fix
└── .github/workflows/      # CI/CD: ci-local, deploy, terraform, agentes
```

---

## 🛡️ FinOps & Failsafe de Custo

* **Instâncias SPOT**: Redução de até 90% no custo computacional.
* **Destruição Automatizada**: O workflow `cost-failsafe.yml` roda periodicamente e destrói o ambiente em nuvem se o orçamento mensal for atingido.
* **Regra Fundamental**: O ambiente em nuvem deve permanecer destruído quando fora de uso para garantir **custo R$ 0,00**.
