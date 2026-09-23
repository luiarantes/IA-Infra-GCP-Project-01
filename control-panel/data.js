window.AIOPS_DATA = {
  "project_id": "ia-infra-gcp-project-01",
  "cluster_name": "aiops-gke",
  "cluster_location": "us-central1-a",
  "active_env": "local",
  "last_synced_at": "2026-09-23T01:33:31.655766+00:00",
  "services": [
    {
      "id": "openobserve",
      "name": "OpenObserve Web UI",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Plataforma unificada de telemetria colunar: Traces OTel em cascata, logs estruturados correlacionados e m\u00e9tricas Prometheus.",
      "icon": "activity",
      "local_url": "http://localhost:5080",
      "local_port": 5080,
      "gcp_url": "http://35.224.35.239:5080",
      "credentials": {
        "user": "admin@example.com",
        "pass": "ComplexPassword123#"
      },
      "health_path": "/api/default/version",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "grafana",
      "name": "Grafana OSS",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Visualiza\u00e7\u00e3o LGTM: Dashboards pr\u00e9-provisionados AIOps Platform Overview, BuscaCEP APM, Loki Logs e Tempo Traces.",
      "icon": "bar-chart",
      "local_url": "http://localhost:3000",
      "local_port": 3000,
      "gcp_url": "http://104.154.156.205:3000",
      "credentials": {
        "user": "admin",
        "pass": "admin"
      },
      "health_path": "/api/health",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "pyroscope",
      "name": "Grafana Pyroscope",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Continuous Profiling cont\u00ednuo de CPU e aloca\u00e7\u00e3o de mem\u00f3ria (Heap/Flamegraphs) sem overhead percept\u00edvel.",
      "icon": "flame",
      "local_url": "http://localhost:4040",
      "local_port": 4040,
      "gcp_url": "http://34.173.200.58:4040",
      "credentials": null,
      "health_path": null,
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "chaos_dashboard",
      "name": "Chaos Mesh Dashboard",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Interface visual de Chaos Engineering: cria\u00e7\u00e3o, inspe\u00e7\u00e3o de falhas injetadas (lat\u00eancia, 500, OOM) e timeline de resili\u00eancia.",
      "icon": "zap",
      "local_url": "http://localhost:2333",
      "local_port": 2333,
      "gcp_url": "http://<PENDING>:2333",
      "credentials": null,
      "health_path": "/api/common/version",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "k6_dashboard",
      "name": "k6 Web Dashboard",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Interface gr\u00e1fica em tempo real do Grafana k6: Throughput (RPS), lat\u00eancia p90/p95, VUs ativas e taxas de erro sob carga.",
      "icon": "gauge",
      "local_url": "http://localhost:5665",
      "local_port": 5665,
      "gcp_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": false,
      "is_on_demand": true,
      "reports_count": 2,
      "latest_report_url": "../load-test/reports/k6-report-20260918_235932.html",
      "platforms": [
        "local"
      ]
    },
    {
      "id": "gcp_monitoring",
      "name": "Cloud Monitoring (Dashboards)",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Console oficial do Google Cloud Monitoring com visualiza\u00e7\u00e3o de m\u00e9tricas e dashboards de infraestrutura do cluster GKE.",
      "icon": "cloud",
      "local_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/dashboards?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_metrics_explorer",
      "name": "GMP - Metrics Explorer",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Google Managed Prometheus: explorador de s\u00e9ries temporais para consultas ad-hoc PromQL (taxa de requisi\u00e7\u00f5es, lat\u00eancia, erros 5xx).",
      "icon": "search",
      "local_url": "https://console.cloud.google.com/monitoring/metrics-explorer?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/metrics-explorer?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_logging",
      "name": "Cloud Logging Explorer",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Logs centralizados de todos os containers e n\u00f3s do cluster GKE com suporte a consultas estruturadas.",
      "icon": "file-text",
      "local_url": "https://console.cloud.google.com/logs/query?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/logs/query?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_alerting",
      "name": "Cloud Monitoring (Alertas & Incidentes)",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Central de incidentes e 5 pol\u00edticas de alerta em nuvem (Golden Signals: reinicializa\u00e7\u00f5es, 5xx, satura\u00e7\u00e3o de CPU/RAM e lat\u00eancia).",
      "icon": "bell",
      "local_url": "https://console.cloud.google.com/monitoring/alerting?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/monitoring/alerting?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_trace",
      "name": "Google Cloud Trace",
      "category": "observability",
      "category_name": "Observabilidade & APM",
      "description": "Visualizador de rastreamento distribu\u00eddo (Distributed Tracing) em nuvem, correlacionado via CloudTraceSpanExporter.",
      "icon": "shuffle",
      "local_url": "https://console.cloud.google.com/traces/overview?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/traces/overview?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "buscacep_web",
      "name": "BuscaCEP (Aplica\u00e7\u00e3o Web)",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Interface web gr\u00e1fica do usu\u00e1rio para consulta de CEPs em tempo real com mapa, formul\u00e1rio interativo e hist\u00f3rico.",
      "icon": "globe",
      "local_url": "http://localhost:8000/",
      "local_port": 8000,
      "gcp_url": "http://34.135.107.35/",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "buscacep_docs",
      "name": "BuscaCEP API (Swagger Docs)",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Documenta\u00e7\u00e3o interativa Swagger UI da API BuscaCEP (FastAPI), consulta de CEPs e despacho de eventos.",
      "icon": "code",
      "local_url": "http://localhost:8000/docs",
      "local_port": 8000,
      "gcp_url": "http://34.135.107.35/docs",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "buscacep_redoc",
      "name": "BuscaCEP (ReDoc)",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Especifica\u00e7\u00e3o formal e documenta\u00e7\u00e3o t\u00e9cnica OpenAPI da API BuscaCEP no formato ReDoc.",
      "icon": "file-text",
      "local_url": "http://localhost:8000/redoc",
      "local_port": 8000,
      "gcp_url": "http://34.135.107.35/redoc",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "buscacep_health",
      "name": "BuscaCEP Healthz",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Endpoint de integridade e liveness probe do BuscaCEP API e conectividade com o worker.",
      "icon": "heart",
      "local_url": "http://localhost:8000/healthz",
      "local_port": 8000,
      "gcp_url": "http://34.135.107.35/healthz",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "gateway_docs",
      "name": "Gateway API (Swagger Docs)",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Documenta\u00e7\u00e3o interativa Swagger UI do Gateway de microsservi\u00e7os para teste de rotas (/work e /api/cep).",
      "icon": "code",
      "local_url": "http://localhost:8080/docs",
      "local_port": 8080,
      "gcp_url": "http://34.60.133.1:8080/docs",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "gateway",
      "name": "Gateway de Microsservi\u00e7os",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Ponto de entrada unificado para os 4 microsservi\u00e7os (Gateway -> Service-API -> Pub/Sub -> Worker -> Downstream).",
      "icon": "layers",
      "local_url": "http://localhost:8080/healthz",
      "local_port": 8080,
      "gcp_url": "http://34.60.133.1:8080/healthz",
      "credentials": null,
      "health_path": "/healthz",
      "is_external": false,
      "platforms": [
        "local",
        "gcp"
      ]
    },
    {
      "id": "pubsub_emulator",
      "name": "Google Pub/Sub",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Mensageria ass\u00edncrona orientada a eventos. Emulador local na porta 8085 e t\u00f3picos gerenciados no GCP.",
      "icon": "inbox",
      "local_url": "http://localhost:8085",
      "local_port": 8085,
      "gcp_url": "https://console.cloud.google.com/cloudpubsub/topic/list?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": false,
      "platforms": [
        "local"
      ]
    },
    {
      "id": "minio_console",
      "name": "MinIO S3 Console",
      "category": "apps",
      "category_name": "Aplica\u00e7\u00f5es & Microsservi\u00e7os",
      "description": "Console Web de Armazenamento S3 (modo distribu\u00eddo) para persist\u00eancia de blocos do Loki e traces do Tempo.",
      "icon": "database",
      "local_url": "http://localhost:9001",
      "local_port": 9001,
      "gcp_url": "https://console.cloud.google.com/storage/browser?project=ia-infra-gcp-project-01",
      "credentials": {
        "user": "minioadmin",
        "pass": "minioadmin"
      },
      "health_path": null,
      "is_external": false,
      "platforms": [
        "local"
      ]
    },
    {
      "id": "gcp_gke",
      "name": "GKE Workloads & Cluster",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Gerenciamento de workloads, pods, deployments, r\u00e9plicas e n\u00f3s SPOT do cluster GKE aiops-gke.",
      "icon": "server",
      "local_url": "https://console.cloud.google.com/kubernetes/workload/overview?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/kubernetes/workload/overview?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_artifact_registry",
      "name": "Artifact Registry (Imagens)",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Reposit\u00f3rio de cont\u00eaineres Docker do projeto (sample-app) na regi\u00e3o us-central1.",
      "icon": "archive",
      "local_url": "https://console.cloud.google.com/artifacts/docker/ia-infra-gcp-project-01/us-central1/sample-app?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/artifacts/docker/ia-infra-gcp-project-01/us-central1/sample-app?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_billing",
      "name": "FinOps & Billing GCP",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Acompanhamento de custos, or\u00e7amentos e relat\u00f3rios de faturamento da conta (BRL) para garantir custo zero quando ocioso.",
      "icon": "dollar-sign",
      "local_url": "https://console.cloud.google.com/billing/012B38-2503FB-1D53DF?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/billing/012B38-2503FB-1D53DF?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
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
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "gcp_iam_workload_identity",
      "name": "IAM & Workload Identity",
      "category": "gcp",
      "category_name": "Plataforma GCP & FinOps",
      "description": "Painel de controle de identidades seguras Keyless OIDC, Service Accounts e federa\u00e7\u00e3o com GitHub Actions.",
      "icon": "shield",
      "local_url": "https://console.cloud.google.com/iam-admin/iam?project=ia-infra-gcp-project-01",
      "gcp_url": "https://console.cloud.google.com/iam-admin/iam?project=ia-infra-gcp-project-01",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "gcp"
      ]
    },
    {
      "id": "github_actions_infra",
      "name": "GitHub Actions (Infra)",
      "category": "aiops",
      "category_name": "Automa\u00e7\u00e3o & Self-Healing",
      "description": "Esteiras de provisionamento (terraform-apply, terraform-destroy), deploy de observabilidade e microsservi\u00e7os.",
      "icon": "play-circle",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/actions",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/actions",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "aiops"
      ]
    },
    {
      "id": "github_actions_app",
      "name": "GitHub Actions (App BuscaCEP)",
      "category": "aiops",
      "category_name": "Automa\u00e7\u00e3o & Self-Healing",
      "description": "Esteiras CI/CD de testes e deploy da aplica\u00e7\u00e3o BuscaCEP no cluster GKE.",
      "icon": "play-circle",
      "local_url": "https://github.com/luiarantes/IA-App-GCP-Project-01/actions",
      "gcp_url": "https://github.com/luiarantes/IA-App-GCP-Project-01/actions",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "aiops"
      ]
    },
    {
      "id": "agent_findings",
      "name": "Achados dos Agentes (Findings)",
      "category": "aiops",
      "category_name": "Automa\u00e7\u00e3o & Self-Healing",
      "description": "Incidentes e anomalias operacionais detectados automaticamente pelos agentes de diagn\u00f3stico.",
      "icon": "alert-triangle",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/issues?q=label%3Aagent-finding",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/issues?q=label%3Aagent-finding",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "aiops"
      ]
    },
    {
      "id": "agent_prs",
      "name": "Corre\u00e7\u00f5es Propostas (PRs)",
      "category": "aiops",
      "category_name": "Automa\u00e7\u00e3o & Self-Healing",
      "description": "Pull Requests com corre\u00e7\u00f5es autom\u00e1ticas de c\u00f3digo e infraestrutura propostas pelo agente de remedia\u00e7\u00e3o.",
      "icon": "git-pull-request",
      "local_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/pulls?q=label%3Aagent-fix",
      "gcp_url": "https://github.com/luiarantes/IA-Infra-GCP-Project-01/pulls?q=label%3Aagent-fix",
      "credentials": null,
      "health_path": null,
      "is_external": true,
      "platforms": [
        "aiops"
      ]
    }
  ],
  "quick_commands": [
    {
      "description": "Sincronizar e abrir o painel de controle",
      "command": "make panel",
      "platform": "all"
    },
    {
      "description": "Iniciar tr\u00e1fego cont\u00ednuo de observabilidade (k6)",
      "command": "make local-traffic-start",
      "platform": "local"
    },
    {
      "description": "Parar gerador de tr\u00e1fego cont\u00ednuo",
      "command": "make local-traffic-stop",
      "platform": "local"
    },
    {
      "description": "Testar fluxo end-to-end via terminal",
      "command": "make local-test",
      "platform": "local"
    },
    {
      "description": "Verificar pods e consumo CPU/Mem\u00f3ria",
      "command": "make local-status",
      "platform": "local"
    },
    {
      "description": "Abrir Chaos Mesh Dashboard no navegador",
      "command": "make chaos-ui",
      "platform": "local"
    },
    {
      "description": "Executar teste de carga com k6 Web Dashboard ao vivo",
      "command": "make k6-ui",
      "platform": "local"
    },
    {
      "description": "Executar Smoke Test r\u00e1pido de valida\u00e7\u00e3o E2E (k6)",
      "command": "make smoke-test",
      "platform": "local"
    },
    {
      "description": "Gerar relat\u00f3rio gr\u00e1fico HTML export\u00e1vel do k6",
      "command": "make k6-report",
      "platform": "local"
    },
    {
      "description": "Disparar Terraform Apply no GCP via GitHub Actions",
      "command": "make gcp-up",
      "platform": "gcp"
    },
    {
      "description": "Disparar Terraform Destroy no GCP via GitHub Actions",
      "command": "make gcp-down",
      "platform": "gcp"
    },
    {
      "description": "Conectar kubectl ao cluster GKE (us-central1-a)",
      "command": "gcloud container clusters get-credentials aiops-gke --zone us-central1-a --project ia-infra-gcp-project-01",
      "platform": "gcp"
    },
    {
      "description": "Verificar workloads e servi\u00e7os no namespace apps (GKE)",
      "command": "kubectl get pods,svc -n apps",
      "platform": "gcp"
    },
    {
      "description": "Demonstra\u00e7\u00e3o completa de Self-Healing em loop fechado",
      "command": "make local-aiops-demo",
      "platform": "aiops"
    },
    {
      "description": "Injetar anomalia de probe crash no cluster",
      "command": "make local-aiops-chaos SCENARIO=probe-crash",
      "platform": "aiops"
    },
    {
      "description": "Executar Agente 1 (Diagn\u00f3stico IA de Logs & M\u00e9tricas)",
      "command": "make local-aiops-analyze",
      "platform": "aiops"
    },
    {
      "description": "Executar Agente 2 (Gerador de Pull Request & Fix)",
      "command": "make local-aiops-fix ISSUE=probe-crash",
      "platform": "aiops"
    },
    {
      "description": "Executar Agente 3 (Valida\u00e7\u00e3o da Corre\u00e7\u00e3o)",
      "command": "make local-aiops-verify ISSUE=probe-crash",
      "platform": "aiops"
    },
    {
      "description": "CLI unificado de Engenharia de Caos e Troubleshooting",
      "command": "make tshoot",
      "platform": "aiops"
    }
  ],
  "k6_reports": [
    {
      "id": "k6_report_k6-report-20260918_235932",
      "filename": "k6-report-20260918_235932.html",
      "title": "Relat\u00f3rio de Carga k6 (18/09/2026 23:59:47)",
      "timestamp": "18/09/2026 23:59:47",
      "size": "164.4 KB",
      "relative_url": "../load-test/reports/k6-report-20260918_235932.html",
      "is_latest": true
    },
    {
      "id": "k6_report_k6-report-20260918_234529",
      "filename": "k6-report-20260918_234529.html",
      "title": "Relat\u00f3rio de Carga k6 (18/09/2026 23:44:59)",
      "timestamp": "18/09/2026 23:44:59",
      "size": "163.8 KB",
      "relative_url": "../load-test/reports/k6-report-20260918_234529.html",
      "is_latest": false
    }
  ]
};
