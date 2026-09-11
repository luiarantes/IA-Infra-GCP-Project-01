# AIOps Platform — Multi-Target IaC, Observability & Self-Healing

Plataforma Kubernetes efêmera, declarativa e multi-nuvem (**Local Kind**, **GCP GKE Standard SPOT** e **AWS EKS [Em Desenvolvimento]**), provisionada inteiramente por código (**Terraform**) com observabilidade 100% agnóstica (**OpenTelemetry + OpenObserve**) e agentes de IA que detectam incidentes, investigam a causa raiz e abrem Pull Requests de correção — sempre com aprovação humana obrigatória.

---

## 🏗️ Arquitetura Multi-Target

```
                                  [ TERRAFORM IAC UNIFICADO ]
                                               │
             ┌─────────────────────────────────┼────────────────────────────────┐
             ▼                                 ▼                                ▼
   [ AMBIENTE LOCAL ]                 [ AMBIENTE GCP ]           [ AMBIENTE AWS (EM DESENVOLVIMENTO) ]
 infra/environments/local/          infra/environments/gcp/          infra/environments/aws/
 • Provider: tehcyx/kind            • Provider: google (GKE Spot)    • Status: Scaffold / Em Construção
 • Cluster Kind em Docker           • GKE Standard Zonal (1 nó Spot) • Alvo: AWS EKS (Spot)
 • Pub/Sub Emulator                 • Cloud Pub/Sub Gerenciado       • Alvo: Amazon SQS/SNS
 • OpenObserve (localhost:5080)     • OpenObserve (LoadBalancer IP)  • Alvo: OpenObserve (ALB / NLB)
 • Custo: R$ 0,00                   • Custo: ~R$ 0,08/h              • Roadmap: Próxima Fase
             │                                 │                                │
             └─────────────────────────────────┼────────────────────────────────┘
                                               ▼
                            [ CAMADA DE APLICAÇÃO 100% AGNÓSTICA ]
                            • Microsserviços FastAPI (OTLP HTTP / 4318)
                            • OpenTelemetry Collector Gateway (Two-Tier)
                            • OpenObserve (Armazenamento Colunar Parquet)
                            • In-Cluster AIOps Agent Runner (SQL Parquet)
```

> [!NOTE]
> **Status de Operação dos Ambientes**:
> - 🟢 **Ambiente Local (Kind)**: 100% Operacional (Offline / Custo R$ 0,00).
> - 🟢 **Ambiente Nuvem GCP (GKE Spot)**: 100% Operacional (Efêmero via CI/CD / ~R$ 0,08/h).
> - 🟡 **Ambiente Nuvem AWS (EKS Spot)**: **Em Desenvolvimento / Scaffold** (Estrutura base de IaC em preparação para fases futuras).


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

## 🚀 Como Executar

### Opção 1: Ambiente Local (Kind + Terraform) — 100% Gratuito & Offline

Não exige conta em nuvem nem cartões de crédito.

```bash
# Provisiona o cluster Kind local via Terraform e sobe todos os serviços
make local-up
```

* **Gateway de Entrada**: `http://localhost:8080`
* **BuscaCEP Web & API**: `http://localhost:8000`
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
