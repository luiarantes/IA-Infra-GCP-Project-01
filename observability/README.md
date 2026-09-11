# Stack de Observabilidade Dual-Engine (OpenObserve + Grafana Labs LGTM via OTel Fan-Out)

A plataforma utiliza uma arquitetura de observabilidade **100% agnóstica de fornecedor de nuvem (zero vendor lock-in)** baseada no padrão CNCF **OpenTelemetry (OTel)** operando com pipeline de **Fan-Out** simultâneo para duas stacks completas:
1. **OpenObserve**: Motor colunar de alta performance (Apache Parquet + Apache DataFusion SQL).
2. **Grafana Labs In-Cluster**: Suíte analítica corporativa com **Grafana OSS**, **Tempo** (traces), **Loki** (logs), **Pyroscope** (continuous profiling) e **Beyla** (auto-instrumentação eBPF no kernel).

---

## 🏗️ Arquitetura da Pipeline de Telemetria (Dual-Engine Fan-Out)

```
                       [ Aplicações & Microsserviços ]
                 gateway | service-api | worker | BuscaCEP
                                    │
               (OTLP HTTP :4318)    │   (Auto-instrumentação eBPF no kernel)
                                    ├─── [ Grafana Beyla DaemonSet ]
                                    │    (Sufixo: {service}-ebpf)
                                    ▼
                     [ OpenTelemetry Collector ]
                     (Multiplexer / Fan-Out Pod)
                                    │
             ┌──────────────────────┴──────────────────────┐
             │ (otlphttp/openobserve)                      │ (otlp/tempo + otlphttp/loki)
             ▼                                             ▼
  [ OpenObserve Engine ]                         [ Grafana Labs In-Cluster ]
  (Apache DataFusion + Parquet)                  ├── Grafana Tempo (:3200 / Traces)
             │                                   ├── Grafana Loki  (:3100 / Logs)
             │                                   ├── Pyroscope     (:4040 / Flamegraphs)
             │                                   └── Grafana OSS   (:3000 / Dashboards)
             │                                             ▲
             └─────────────────────────────────────────────┘
                  (OpenObserve Prometheus Datasource)
```

---

## 🔑 Pilares Principais da Arquitetura

1. **Agnosticismo Total & Zero Retrabalho**:
   - Os microsserviços emitem exclusivamente no protocolo padrão CNCF OTLP (`OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318`).
   - O OTel Collector atua como roteador multiplexador (*fan-out*), duplicando e entregando os spans e logs em tempo real tanto para o OpenObserve quanto para a stack Grafana.
2. **Dupla Perspectiva de Tracing (Aplicação vs. Kernel)**:
   - **OTel SDK Manual**: Spans criados pelo código Python/FastAPI (`gateway`, `service-api`, `buscacep-api`).
   - **Grafana Beyla (eBPF)**: Spans capturados pelo kernel do Linux no nível de socket/rede (`gateway-ebpf`, `service-api-ebpf`), permitindo isolar se um gargalo ocorre na rede ou no código.
3. **Correlação Multidimensional (Trace-to-Log & Trace-to-Profile)**:
   - No Grafana, clicar em uma linha de log no **Loki** abre o trace no **Tempo**.
   - O **Pyroscope** captura contínuos perfis de CPU (Flamegraphs) das aplicações.
4. **Modos de Operação FinOps (Toggle no Terraform `grafana_stack_mode`)**:
   - **Modo `simple` (Monolítico Leve)**:
     - Execução single-binary com armazenamento em disco local do container/PVC.
     - Ideal para notebooks e estações de trabalho de desenvolvedores (**mínimo 6 GB RAM / recomendado 8 GB RAM no Docker Desktop**).
     - Custo praticamente nulo no GKE (roda em 1 nó Spot pequeno).
   - **Modo `distributed` (Arquitetura Corporativa de Produção)**:
     - Componentes desacoplados com **Object Storage** como única fonte da verdade (Google Cloud Storage no GCP ou MinIO S3 no Kind local).
     - **Separação CQRS (Escrita vs. Leitura)**: Ingesters recebem milhões de eventos sem sofrer concorrência de CPU/RAM quando usuários executam queries pesadas no Grafana.
     - **Resiliência a Nós Spot**: Como os dados vão direto para o bucket, se um nó Spot for desligado pelo provedor de nuvem, o pod sobe em outro nó sem precisar anexar/desanexar discos físicos.
     - **Economia FinOps**: O armazenamento em Object Storage (GCS/S3 a ~US$ 0,02/GB) custa até **10x menos** que discos SSD Persistent Disk / EBS (~US$ 0,17/GB).
     - Requer **10 a 12 GB de RAM e 4 a 6 vCPUs** no Docker Desktop local para suportar o MinIO e as réplicas desacopladas.

| Modo | Arquitetura | Storage Backend | Requisito Mínimo Docker | Custo Estimado Nuvem | Recomendado Para |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`simple`** | Monolítico Leve | Disco local / PVC | **8 GB RAM / 4 vCPUs** | ~R$ 0,08/h (1 nó Spot) | Estudo local, labs diários e testes pontuais |
| **`distributed`** | Microsserviços Desacoplados | **Object Storage** (GCS / MinIO S3) | **12 GB RAM / 6 vCPUs** | ~R$ 0,25/h (GCS + Nós Spot) | Simulação de ambientes reais de produção corporativa |


---

## 📊 Manifestos Versionados

* [`observability/openobserve.yaml`](openobserve.yaml): Deployment e Service do OpenObserve.
* [`observability/tempo.yaml`](tempo.yaml): Grafana Tempo em modo monolítico leve com receiver OTLP.
* [`observability/loki.yaml`](loki.yaml): Grafana Loki com endpoints nativos OTLP e LogQL.
* [`observability/pyroscope.yaml`](pyroscope.yaml): Grafana Pyroscope para profiling contínuo (Flamegraphs).
* [`observability/beyla.yaml`](beyla.yaml): DaemonSet eBPF para monitoramento transparente no kernel com sufixo `-ebpf`.
* [`observability/grafana.yaml`](grafana.yaml): Grafana OSS com datasources provisionados como código (Tempo, Loki, Pyroscope e OpenObserve).
* [`observability/otel-collector.yaml`](otel-collector.yaml): ConfigMap e Deployment do OTel Collector com Fan-Out configurado.
* [`observability/traffic-generator.yaml`](traffic-generator.yaml): Gerador de tráfego contínuo k6.
* [`observability/distributed/`](distributed/): Manifestos para armazenamento em Google Cloud Storage (GCS) com Workload Identity.

---

## 🚀 Como Acessar as Interfaces

### Ambiente Local (Kind)
* **OpenObserve**: `http://localhost:5080` (comando `make obs-ui`)
  * Login: `admin@example.com` / `ComplexPassword123#`
* **Grafana**: `http://localhost:3000` (comando `make grafana-ui`)
  * Login: `admin` / `admin`
* **Pyroscope**: `http://localhost:4040` (comando `make pyroscope-ui`)
* **Gateway de Entrada**: `http://localhost:8080`
* **BuscaCEP Web/API**: `http://localhost:8000`

### Ambiente GCP GKE
Tanto o OpenObserve quanto o Grafana são provisionados como `type: LoadBalancer` e recebem IPs públicos diretos exibidos no final do workflow `deploy-observability.yml` no GitHub Actions.
