# Ambiente de Simulação Local AIOps (Kind + OpenObserve + OTel Collector)

Este diretório contém a infraestrutura e a automação para executar a **plataforma AIOps 100% localmente no seu computador**, com paridade de arquitetura e comportamento em relação ao **Google Cloud Platform (GKE Autopilot + Pub/Sub + Cloud Monitoring + Agentes)**.

O objetivo deste ambiente é permitir desenvolvimento, testes de observabilidade, execução de chaos engineering e testes de agentes de self-healing a **custo zero (R$ 0,00)** e com ciclo de feedback imediato.

---

## 🏛️ Arquitetura da Solução Local

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLUSTER LOCAL (KIND)                              │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Infraestrutura & Observabilidade                                      │  │
│  │  - Metrics-Server: Habilita "kubectl top pods" e escalonamento HPA    │  │
│  │  - Google Pub/Sub Emulator (porta 8085): Mensageria em memória        │  │
│  │  - OpenTelemetry Collector: Recebe OTLP, scrape de métricas e filtros │  │
│  │  - OpenObserve (porta 5080): Armazenamento colunar Parquet            │  │
│  │    (Traces, Logs com correlação e Métricas Prometheus)                │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Microsserviços da Infra (apps/)                                       │  │
│  │  - Gateway (porta 8080) ──▶ Service-API ──▶ Pub/Sub ──▶ Worker ──▶ DS  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Aplicação BuscaCEP (Apps/)                                            │  │
│  │  - BuscaCEP API (porta 8000) ──▶ Pub/Sub ──▶ BuscaCEP Worker          │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Gerador de Tráfego & Testes (K8s)                                     │  │
│  │  - Continuous Traffic Generator (k6 background deployment)            │  │
│  │  - Load Test & Chaos Engineering Jobs                                 │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                ▲
                                │ Interage via Kubeconfig montado
┌──────────────────────────────┴──────────────────────────────────────────────┐
│                  CONTAINER DO AGENTE SELF-HEALING (Runner)                  │
│  - Imagem Docker 'aiops-agent-runner' executando isoladamente               │
│  - Executa pre-checks determinísticos dos 5 sinais e tarefas de IA          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Paridade Técnica: Local vs Nuvem (GCP)

| Recurso / Capacidade | Ambiente Nuvem (GCP) | Ambiente Local (Kind) |
|---|---|---|
| **Orquestração** | GKE Autopilot (`aiops-gke`) | Kind (`aiops-local`) v1.30 |
| **Ingress / Rede** | Cloud Load Balancing (`LoadBalancer`) | Port Mappings Kind (`8080`, `8000`, `5080`, `8085`) |
| **Métricas de Pod & HPA** | GKE Metrics Server nativo | `metrics-server` v0.7.2 |
| **Mensageria Assíncrona**| Google Cloud Pub/Sub Gerenciado | Google Cloud SDK Pub/Sub Emulator |
| **Tracing & Logs** | Cloud Trace / Cloud Logging | **OpenObserve** v0.14.7 (Parquet) |
| **Pipeline de Telemetria**| Agentes de telemetria GCP | **OpenTelemetry Collector** Contrib v0.108 |
| **Agente Self-Healing** | GitHub Actions Runner (Ubuntu) | Container Docker `aiops-agent-runner` |
| **Custo de Execução** | Orçamento efêmero FinOps | **R$ 0,00 (Totalmente local)** |

---

## 🛠️ Pré-requisitos

1. **Docker Desktop** ativo.
2. **Kind CLI**:
   ```bash
   brew install kind
   ```
3. **kubectl**:
   ```bash
   brew install kubectl
   ```

---

## 🚀 Guia Rápido de Comandos (`Makefile`)

Todos os comandos de gerenciamento do ambiente local são executados na raiz do repositório da Infra:

### 1. Subir o Ambiente Completo
Compila as imagens locais, cria o cluster Kind, instala serviços de infraestrutura e aplica todos os manifestos:
```bash
make local-up
```

### 2. Verificar Status e Consumo de Recursos
Exibe todos os pods e o consumo de CPU/Memória em tempo real via Metrics-Server:
```bash
make local-status
```

### 3. Testar End-to-End
Envia requisições de teste para o Gateway dos microsserviços e para a API do BuscaCEP:
```bash
make local-test
```

### 4. Gerar Tráfego Contínuo para o OpenObserve
Inicia um gerador de tráfego contínuo e suave em background (2 VUs, ~2 req/s) para alimentar traces, logs e métricas em tempo real no OpenObserve:
```bash
make local-traffic-start
```

Para pausar o tráfego contínuo:
```bash
make local-traffic-stop
```

### 5. Executar Teste de Carga Intenso (k6)
Executa o Job do k6 simulando rampa de até 50 usuários virtuais para observar o escalonamento automático do HPA:
```bash
make local-load-test
```

### 6. Executar Teste de Chaos Engineering
Injeta falhas controladas no cluster local:
```bash
make local-chaos-test
```

### 7. Executar o Agente Self-Healing em Container
Roda o container isolado do agente para diagnosticar os 5 sinais operacionais no cluster local:
```bash
make local-agent
```

### 8. Destruir o Ambiente Local
Remove o cluster Kind e libera todos os recursos de memória e disco:
```bash
make local-down
```

---

## 📊 Acesso e Exploração do OpenObserve

- **URL de Acesso:** [http://localhost:5080](http://localhost:5080)
- **Usuário:** `admin@example.com`
- **Senha:** `ComplexPassword123#`

### Principais Telas:
1. **Traces:** Menu **Traces** ➔ Stream `default` ➔ Filtre por `operation_name = 'POST /work'` para ver a árvore em cascata (*waterfall*) entre os 4 microsserviços.
2. **Logs:** Menu **Logs** ➔ Stream `default` ➔ Visualize logs estruturados emitidos com `trace_id` e `span_id` correlacionados.
3. **Metrics:** Menu **Metrics** ➔ Visualize métricas dos pods coletadas pelo scraper Prometheus do OTel Collector.
