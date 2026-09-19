// Catálogo de links e recursos da Plataforma AIOps (Offline-first data store)
// Atualizado automaticamente por scripts/sync_control_panel.py
window.AIOPS_DATA = {
  "project_id": "ia-infra-gcp-project-01",
  "cluster_name": "aiops-gke",
  "cluster_location": "us-central1-a",
  "active_env": "local",
  "last_synced_at": "2026-09-19T02:45:40.772940+00:00",
  "services": [
    {
      "id": "openobserve",
      "name": "OpenObserve Web UI",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Plataforma unificada de telemetria colunar: Traces OTel em cascata, logs estruturados correlacionados e métricas Prometheus.",
      "icon": "activity",
      "local_url": "http://localhost:5080",
      "local_port": 5080,
      "gcp_url": "http://<PENDING>:5080",
      "credentials": {
        "user": "admin@example.com",
        "pass": "ComplexPassword123#"
      },
      "health_path": "/api/default/version",
      "is_external": false
    },
    {
      "id": "grafana",
      "name": "Grafana OSS",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Visualização LGTM: Dashboards pré-provisionados AIOps Platform Overview, BuscaCEP APM, Loki Logs e Tempo Traces.",
      "icon": "bar-chart",
      "local_url": "http://localhost:3000",
      "local_port": 3000,
      "gcp_url": "http://localhost:3000",
      "credentials": {
        "user": "admin",
        "pass": "admin"
      },
      "health_path": "/api/health",
      "is_external": false
    },
    {
      "id": "pyroscope",
      "name": "Grafana Pyroscope",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Continuous Profiling contínuo de CPU e alocação de memória (Heap/Flamegraphs) sem overhead perceptível.",
      "icon": "flame",
      "local_url": "http://localhost:4040",
      "local_port": 4040,
      "gcp_url": "http://<PENDING>:4040",
      "credentials": null,
      "health_path": null,
      "is_external": false
    },
    {
      "id": "chaos_dashboard",
      "name": "Chaos Mesh Dashboard",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Interface visual de Chaos Engineering: criação, inspeção de falhas injetadas (latência, 500, OOM) e timeline de resiliência.",
      "icon": "zap",
      "local_url": "http://localhost:2333",
      "local_port": 2333,
      "gcp_url": "http://<PENDING>:2333",
      "credentials": null,
      "health_path": "/api/common/version",
      "is_external": false
    },
    {
      "id": "k6_dashboard",
      "name": "k6 Web Dashboard",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Interface gráfica em tempo real do Grafana k6: Throughput (RPS), latência p90/p95, VUs ativas e taxas de erro sob carga.",
      "icon": "gauge",
      "local_url": "http://localhost:5665",
      "local_port": 5665,
      "gcp_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": false,
      "is_on_demand": true,
      "reports_count": 1,
      "latest_report_url": "../load-test/reports/k6-report-20260918_234529.html"
    },
    {
      "id": "gcp_monitoring",
      "name": "Cloud Monitoring (Dashboards)",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Console oficial do Google Cloud Monitoring com visualização de métricas e dashboards de infraestrutura do cluster GKE.",
      "icon": "cloud",
      "local_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_metrics_explorer",
      "name": "GMP - Metrics Explorer",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Google Managed Prometheus: explorador de séries temporais para consultas ad-hoc PromQL (taxa de requisições, latência, erros 5xx).",
      "icon": "search",
      "local_url": "https://console.cloud.google.com/monitoring/metrics-explorer?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/metrics-explorer?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_logging",
      "name": "Cloud Logging Explorer",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Logs centralizados de todos os containers e nós do cluster GKE com suporte a consultas estruturadas.",
      "icon": "file-text",
      "local_url": "https://console.cloud.google.com/logs/query?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/logs/query?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_alerting",
      "name": "Cloud Monitoring (Alertas & Incidentes)",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Central de incidentes e 5 políticas de alerta em nuvem (Golden Signals: reinicializações, 5xx, saturação de CPU/RAM e latência).",
      "icon": "bell",
      "local_url": "https://console.cloud.google.com/monitoring/alerting?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/alerting?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_trace",
      "name": "Google Cloud Trace",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Visualizador de rastreamento distribuído (Distributed Tracing) em nuvem, correlacionado via CloudTraceSpanExporter.",
      "icon": "shuffle",
      "local_url": "https://console.cloud.google.com/traces/overview?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/traces/overview?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "buscacep_web",
      "name": "BuscaCEP (Aplicação Web)",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Interface web gráfica do usuário para consulta de CEPs em tempo real com mapa, formulário interativo e histórico.",
      "icon": "globe",
      "local_url": "http://localhost:8000/",
      "local_port": 8000,
      "gcp_url": "http://<PENDING>/",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "buscacep_docs",
      "name": "BuscaCEP API (Swagger Docs)",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Documentação interativa Swagger UI da API BuscaCEP (FastAPI), consulta de CEPs e despacho de eventos.",
      "icon": "code",
      "local_url": "http://localhost:8000/docs",
      "local_port": 8000,
      "gcp_url": "http://<PENDING>/docs",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "buscacep_redoc",
      "name": "BuscaCEP (ReDoc)",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Especificação formal e documentação técnica OpenAPI da API BuscaCEP no formato ReDoc.",
      "icon": "file-text",
      "local_url": "http://localhost:8000/redoc",
      "local_port": 8000,
      "gcp_url": "http://<PENDING>/redoc",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "buscacep_health",
      "name": "BuscaCEP Healthz",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Endpoint de integridade e liveness probe do BuscaCEP API e conectividade com o worker.",
      "icon": "heart",
      "local_url": "http://localhost:8000/healthz",
      "local_port": 8000,
      "gcp_url": "http://<PENDING>/healthz",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "gateway_docs",
      "name": "Gateway API (Swagger Docs)",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Documentação interativa Swagger UI do Gateway de microsserviços para teste de rotas (/work e /api/cep).",
      "icon": "code",
      "local_url": "http://localhost:8080/docs",
      "local_port": 8080,
      "gcp_url": "http://<PENDING>:8080/docs",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "gateway",
      "name": "Gateway de Microsserviços",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Ponto de entrada unificado para os 4 microsserviços (Gateway -> Service-API -> Pub/Sub -> Worker -> Downstream).",
      "icon": "layers",
      "local_url": "http://localhost:8080/healthz",
      "local_port": 8080,
      "gcp_url": "http://<PENDING>:8080/healthz",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false
    },
    {
      "id": "pubsub_emulator",
      "name": "Google Pub/Sub",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Mensageria assíncrona orientada a eventos. Emulador local na porta 8085 e tópicos gerenciados no GCP.",
      "icon": "inbox",
      "local_url": "http://localhost:8085",
      "local_port": 8085,
      "gcp_url": "https://console.cloud.google.com/cloudpubsub/topic/list?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": false
    },
    {
      "id": "minio_console",
      "name": "MinIO S3 Console",
      "category": "apps",
      "category_name": "Aplicações & Microsserviços",
      "description": "Console Web de Armazenamento S3 (modo distribuído) para persistência de blocos do Loki e traces do Tempo.",
      "icon": "database",
      "local_url": "http://localhost:9001",
      "local_port": 9001,
      "gcp_url": "https://console.cloud.google.com/storage/browser?project=ia-infra-gcp-project-01",
      "credentials": {
        "user": "minioadmin",
        "pass": "minioadmin"
      },
      "health_path": null,
      "is_external": false
    },
    {
      "id": "gcp_gke",
      "name": "GKE Workloads & Cluster",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Gerenciamento de workloads, pods, deployments, réplicas e nós SPOT do cluster GKE aiops-gke.",
      "icon": "server",
      "local_url": "https://console.cloud.google.com/kubernetes/workload/overview?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/kubernetes/workload/overview?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_artifact_registry",
      "name": "Artifact Registry (Imagens)",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Repositório de contêineres Docker do projeto (sample-app) na região us-central1.",
      "icon": "archive",
      "local_url": "https://console.cloud.google.com/artifacts/docker/ia-infra-gcp-project-01/us-central1/sample-app?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/artifacts/docker/ia-infra-gcp-project-01/us-central1/sample-app?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_billing",
      "name": "FinOps & Billing GCP",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Acompanhamento de custos, orçamentos e relatórios de faturamento da conta (BRL) para garantir custo zero quando ocioso.",
      "icon": "dollar-sign",
      "local_url": "https://console.cloud.google.com/billing/012B38-2503FB-1D53DF?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/billing/012B38-2503FB-1D53DF?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_storage_tfstate",
      "name": "Cloud Storage (Bucket State)",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Bucket de armazenamento de alta disponibilidade do estado remoto do Terraform (ia-infra-gcp-project-01-tfstate).",
      "icon": "database",
      "local_url": "https://console.cloud.google.com/storage/browser/ia-infra-gcp-project-01-tfstate?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/storage/browser/ia-infra-gcp-project-01-tfstate?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "gcp_iam_workload_identity",
      "name": "IAM & Workload Identity",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Painel de controle de identidades seguras Keyless OIDC, Service Accounts e federação com GitHub Actions.",
      "icon": "shield",
      "local_url": "https://console.cloud.google.com/iam-admin/iam?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/iam-admin/iam?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "github_actions_infra",
      "name": "GitHub Actions (Infra)",
      "category": "aiops",
      "category_name": "Automação & Self-Healing",
      "description": "Esteiras de provisionamento (terraform-apply, terraform-destroy), deploy de observabilidade e microsserviços.",
      "icon": "play-circle",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/actions",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/actions",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "github_actions_app",
      "name": "GitHub Actions (App BuscaCEP)",
      "category": "aiops",
      "category_name": "Automação & Self-Healing",
      "description": "Esteiras CI/CD de testes e deploy da aplicação BuscaCEP no cluster GKE.",
      "icon": "play-circle",
      "local_url": "https://github.com/luiarantes/IA-App-GCP-Project-01/actions",
      "gcp_url": "https://github.com/luiarantes/IA-App-GCP-Project-01/actions",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "agent_findings",
      "name": "Achados dos Agentes (Findings)",
      "category": "aiops",
      "category_name": "Automação & Self-Healing",
      "description": "Incidentes e anomalias operacionais detectados automaticamente pelos agentes de diagnóstico.",
      "icon": "alert-triangle",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/issues?q=label%3Aagent-finding",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/issues?q=label%3Aagent-finding",
      "credentials": null,
      "health_path": null,
      "is_external": true
    },
    {
      "id": "agent_prs",
      "name": "Correções Propostas (PRs)",
      "category": "aiops",
      "category_name": "Automação & Self-Healing",
      "description": "Pull Requests com correções automáticas de código e infraestrutura propostas pelo agente de remediação.",
      "icon": "git-pull-request",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/pulls?q=label%3Aagent-fix",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/pulls?q=label%3Aagent-fix",
      "credentials": null,
      "health_path": null,
      "is_external": true
    }
  ],
  "quick_commands": [
    {
      "description": "Sincronizar e abrir o painel de controle",
      "command": "make panel"
    },
    {
      "description": "Iniciar tráfego contínuo de observabilidade (k6)",
      "command": "make local-traffic-start"
    },
    {
      "description": "Parar gerador de tráfego contínuo",
      "command": "make local-traffic-stop"
    },
    {
      "description": "Testar fluxo end-to-end via terminal",
      "command": "make local-test"
    },
    {
      "description": "Verificar pods e consumo CPU/Memória",
      "command": "make local-status"
    },
    {
      "description": "Executar Agente 1 (Diagnóstico IA)",
      "command": "make local-aiops-analyze"
    },
    {
      "description": "Abrir Chaos Mesh Dashboard no navegador",
      "command": "make chaos-ui"
    },
    {
      "description": "Executar teste de carga com k6 Web Dashboard ao vivo",
      "command": "make k6-ui"
    },
    {
      "description": "Executar Smoke Test rápido de validação E2E (k6)",
      "command": "make smoke-test"
    },
    {
      "description": "Gerar relatório gráfico HTML exportável do k6",
      "command": "make k6-report"
    }
  ],
  "k6_reports": [
    {
      "id": "k6_report_k6-report-20260918_234529",
      "filename": "k6-report-20260918_234529.html",
      "title": "Relatório de Carga k6 (18/09/2026 23:44:59)",
      "timestamp": "18/09/2026 23:44:59",
      "size": "163.8 KB",
      "relative_url": "../load-test/reports/k6-report-20260918_234529.html",
      "is_latest": true
    }
  ]
};
