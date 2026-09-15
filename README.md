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

### ⚙️ Guia de Configuração: Toggles de Ambiente e Observabilidade

A plataforma utiliza variáveis declarativas do Terraform (`terraform.tfvars`) para alternar recursos de infraestrutura e observabilidade tanto no ambiente local quanto na nuvem:

| Toggle / Variável | Onde Configurar (Local) | Onde Configurar (GCP) | Opções | Padrão | Finalidade |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `grafana_stack_mode` | `infra/environments/local/terraform.tfvars` | `infra/environments/test/terraform.tfvars` | `"simple"`, `"distributed"` | `"simple"` | Alterna entre o modo leve monolítico ou desacoplado corporativo (Object Storage via GCS ou MinIO). |
| `enable_gpu_pool` | *N/A (Executa em CPU)* | `infra/environments/test/terraform.tfvars` | `true`, `false` | `true` | Ativa node pool dedicado com GPU NVIDIA Tesla T4 Spot no GKE para aceleração da inferência dos agentes AIOps. |
| `gpu_type` | *N/A* | `infra/environments/test/terraform.tfvars` | `"nvidia-tesla-t4"` | `"nvidia-tesla-t4"` | Tipo de GPU alocada na nuvem GCP. |
| `gpu_machine_type` | *N/A* | `infra/environments/test/terraform.tfvars` | `"n1-standard-4"` | `"n1-standard-4"` | Tipo de VM para o nó acelerado com GPU. |

#### Como Alternar o Ambiente de Execução (Local vs GCP vs AWS)

- **Para rodar Localmente (Kind)**:
  1. Copie o arquivo de exemplo: `cp infra/environments/local/terraform.tfvars.example infra/environments/local/terraform.tfvars`
  2. Ajuste `grafana_stack_mode = "simple"` (ou `"distributed"` se possuir mais de 12 GB RAM).
  3. Execute `make local-up`.
- **Para rodar na Nuvem GCP (GKE Spot + GPU)**:
  1. Copie o arquivo de exemplo: `cp infra/environments/test/terraform.tfvars.example infra/environments/test/terraform.tfvars`
  2. Defina `grafana_stack_mode` conforme a necessidade de armazenamento.
  3. Defina `enable_gpu_pool = true` para usufruir da aceleração por hardware nos agentes de self-healing.
  4. Provisione via CLI (`make gcp-up`) ou pelo workflow do GitHub Actions (`gh workflow run terraform-apply.yml`).
- **Para rodar na Nuvem AWS (EKS Spot)**:
  1. Consulte o scaffold em desenvolvimento no diretório `infra/environments/aws/`.

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

#### ⚠️ Pré-requisitos Importantes da Conta GCP (Upgrade de Faturamento & Cota de GPU)

Para provisionar o ambiente na nuvem com o acelerador de GPU ativo (`enable_gpu_pool = true`), são necessárias duas ações prévias no Console do Google Cloud:

1. **Upgrade da Conta GCP (Sair do Modo Avaliação Gratuita Restrito)**:
   * Por padrão, contas recém-criadas no *Free Trial* permanecem em modo "sandbox" e **bloqueiam totalmente a criação de instâncias com GPU**.
   * Acesse o [Console do GCP](https://console.cloud.google.com/) e clique no botão **"Ativar" / "Upgrade"** no banner superior de Billing.
   * *Fique tranquilo*: O upgrade **não consome nem cancela seus créditos gratuitos restantes** (ex: R$ 1.500 / US$ 300) — ele apenas autoriza sua conta a alocar recursos de computação especializada.
2. **Solicitação de Aumento de Cota de GPU (`NVIDIA_T4_GPUS`)**:
   * Novas contas começam com cota de GPU igual a **0**.
   * Acesse **IAM & Admin** ➔ **Quotas & System Limits** no Console GCP.
   * Filtre pelas métricas:
     * `compute.googleapis.com/gpus_all_regions` (Cota global de GPUs)
     * `compute.googleapis.com/nvidia_t4_gpus` (Região: `us-central1`)
   * Selecione a cota, clique em **Edit Quota** e solicite o limite de **1**. O Google processa e aprova essa solicitação em poucos minutos.
3. **Fallback sem GPU (100% CPU Spot)**:
   * Caso sua solicitação de cota ainda esteja pendente de aprovação ou prefira rodar sem GPU, basta definir `enable_gpu_pool = false` em `infra/environments/test/terraform.tfvars`. O cluster funcionará perfeitamente utilizando apenas nós de CPU Spot (`e2-standard-2`/`e2-standard-4`).

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

### ⚡ Benchmark de Resolução: Local (CPU) vs Nuvem GCP (GPU Spot Tesla T4)

Comparativo real do Tempo Médio de Resolução (MTTR) medido de ponta a ponta durante testes de injeção de falhas com os três agentes autônomos:

| Cenário de Incidente | Ambiente Local (Kind / CPU) | Nuvem GCP (GKE Spot + GPU T4) | Redução no MTTR | Status do Ciclo |
| :--- | :--- | :--- | :--- | :--- |
| **Crash de Pod (`probe-crash`)** | ~8 min 00s | **1 min 45s** (A1: 34s, A2: 50s, A3: 6s) | **-78%** | 🟢 Resolvido & Fechado |
| **Memória Esgotada (`oom-kill`)** | ~11 min 15s | **2 min 15s** (A1: 41s, A2: 57s, A3: 7s) | **-80%** | 🟢 Resolvido & Fechado |

* **Agente 1 (Log Analyzer)**: Detecta anomalias consultando métricas e logs via SQL no OpenObserve em ~35-40s com GPU Spot.
* **Agente 2 (PR Creator)**: Analisa o relatório da Issue, formula a hipótese de causa raiz e abre o Pull Request com a correção de infraestrutura em ~50-60s.
* **Agente 3 (Verify Fix)**: Valida a recuperação pós-deploy checando a estabilização das métricas em menos de 10s.

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
