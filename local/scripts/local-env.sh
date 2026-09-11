#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="aiops-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APPS_REPO_DIR="$(cd "${INFRA_DIR}/../../Apps/IA-App-GCP-Project-01" 2>/dev/null && pwd || echo "")"

check_prereqs() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker não encontrado. Por favor, inicie o Docker Desktop."
        exit 1
    fi
    if ! command -v kind >/dev/null 2>&1; then
        echo "❌ Kind não encontrado. Instale com: brew install kind"
        exit 1
    fi
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "❌ kubectl não encontrado. Instale com: brew install kubectl"
        exit 1
    fi
}

create_cluster() {
    check_prereqs
    echo "🚀 [1/6] Verificando cluster local Kind '${CLUSTER_NAME}'..."
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo "ℹ️ Cluster '${CLUSTER_NAME}' já existe. Usando cluster existente."
    else
        kind create cluster --config "${INFRA_DIR}/local/kind-config.yaml"
    fi
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
}

provision_workloads() {
    local MODE="${1:-${GRAFANA_STACK_MODE:-simple}}"
    check_prereqs
    echo "📊 [2/6] Instalando serviços de infraestrutura local (Metrics-Server, Pub/Sub Emulator, OpenObserve, Grafana Stack [Modo: ${MODE}])..."
    kubectl apply -f "${INFRA_DIR}/local/manifests/metrics-server.yaml"
    kubectl apply -f "${INFRA_DIR}/local/manifests/pubsub-emulator.yaml"
    kubectl apply -f "${INFRA_DIR}/local/manifests/openobserve.yaml"

    if [ "${MODE}" = "distributed" ]; then
        echo "🗄️ Modo Distribuído ativo: provisionando MinIO S3 Object Storage..."
        kubectl apply -f "${INFRA_DIR}/local/manifests/minio.yaml"
        echo "⏳ Aguardando criação dos buckets S3 no MinIO..."
        kubectl wait --for=condition=complete --timeout=60s job/minio-create-buckets -n default || true
        kubectl apply -f "${INFRA_DIR}/observability/distributed/tempo-distributed-local.yaml"
        kubectl apply -f "${INFRA_DIR}/observability/distributed/loki-distributed-local.yaml"
    else
        echo "📦 Modo Simples ativo: provisionando Tempo e Loki com armazenamento local..."
        kubectl apply -f "${INFRA_DIR}/observability/tempo.yaml"
        kubectl apply -f "${INFRA_DIR}/observability/loki.yaml"
    fi

    kubectl apply -f "${INFRA_DIR}/observability/pyroscope.yaml"
    kubectl apply -f "${INFRA_DIR}/observability/beyla.yaml"
    kubectl apply -f "${INFRA_DIR}/observability/grafana-dashboards.yaml"
    kubectl apply -f "${INFRA_DIR}/observability/grafana.yaml"


    echo "🔨 [3/6] Construindo imagens Docker dos microsserviços, do BuscaCEP e do agente..."
    docker build -t gateway:local "${INFRA_DIR}/apps/gateway"
    docker build -t service-api:local "${INFRA_DIR}/apps/service-api"
    docker build -t service-worker:local "${INFRA_DIR}/apps/service-worker"
    docker build -t service-downstream:local "${INFRA_DIR}/apps/service-downstream"
    docker build -t aiops-agent-runner:local "${INFRA_DIR}/agents/runner"

    if [ -n "${APPS_REPO_DIR}" ] && [ -d "${APPS_REPO_DIR}" ]; then
        echo "📦 Construindo imagem do BuscaCEP (App)..."
        docker build -t buscacep:local "${APPS_REPO_DIR}"
    fi

    echo "🚚 [4/6] Carregando imagens Docker para dentro do cluster Kind..."
    kind load docker-image gateway:local --name "${CLUSTER_NAME}"
    kind load docker-image service-api:local --name "${CLUSTER_NAME}"
    kind load docker-image service-worker:local --name "${CLUSTER_NAME}"
    kind load docker-image service-downstream:local --name "${CLUSTER_NAME}"
    if [ -n "${APPS_REPO_DIR}" ] && [ -d "${APPS_REPO_DIR}" ]; then
        kind load docker-image buscacep:local --name "${CLUSTER_NAME}"
    fi

    echo "📄 [5/6] Aplicando manifestos Kubernetes..."
    python3 "${SCRIPT_DIR}/apply_local_manifests.py"

    echo "⏳ [6/6] Aguardando inicialização e prontidão dos pods..."
    kubectl rollout status deployment/metrics-server -n kube-system --timeout=90s || true
    kubectl rollout status deployment/pubsub-emulator --timeout=90s || true
    kubectl rollout status deployment/openobserve --timeout=90s || true
    if [ "${MODE}" = "distributed" ]; then
        kubectl rollout status deployment/minio --timeout=90s || true
    fi
    kubectl rollout status deployment/tempo --timeout=90s || true
    kubectl rollout status deployment/loki --timeout=90s || true
    kubectl rollout status deployment/pyroscope --timeout=90s || true
    kubectl rollout status deployment/grafana --timeout=90s || true
    kubectl rollout status daemonset/beyla --timeout=90s || true
    kubectl rollout status deployment/otel-collector --timeout=90s || true
    kubectl rollout status deployment/gateway --timeout=90s || true
    kubectl rollout status deployment/service-api --timeout=90s || true
    kubectl rollout status deployment/service-worker --timeout=90s || true
    kubectl rollout status deployment/service-downstream --timeout=90s || true
    if [ -n "${APPS_REPO_DIR}" ] && [ -d "${APPS_REPO_DIR}/k8s" ]; then
        kubectl rollout status deployment/buscacep-api --timeout=90s || true
        kubectl rollout status deployment/buscacep-worker --timeout=90s || true
    fi

    echo ""
    echo "================================================================="
    echo " 🎉 Ambiente Local AIOps (Kind) 100% no ar e operacional!"
    echo "    Modo de Observabilidade Grafana: ${MODE}"
    echo "================================================================="
    echo " 🌐 Gateway da Infra (Entrada):   http://localhost:8080"
    echo " 🌐 BuscaCEP Web & API:           http://localhost:8000"
    echo " 📊 OpenObserve (Dashboards/OTel):http://localhost:5080"
    echo "    (Login: admin@example.com / ComplexPassword123#)"
    echo " 📈 Grafana OSS (Loki/Tempo/APM): http://localhost:3000"
    echo "    (Login: admin / admin)"
    echo " 🔥 Pyroscope (Continuous Profile):http://localhost:4040"
    echo " 📬 Google Pub/Sub Emulator:      http://localhost:8085"
    if [ "${MODE}" = "distributed" ]; then
    echo " 🗄️ MinIO S3 Console (Storage):   http://localhost:9001"
    echo "    (Login: minioadmin / minioadmin)"
    fi
    echo "================================================================="
}

cluster_up() {
    local MODE="${1:-${GRAFANA_STACK_MODE:-simple}}"
    create_cluster
    provision_workloads "${MODE}"
}

cluster_down() {
    echo "🛑 Destruindo cluster local Kind '${CLUSTER_NAME}'..."
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "✅ Ambiente local destruído com sucesso. Custo zero e recursos liberados!"
}

cluster_status() {
    echo "=== Pods no namespace default ==="
    kubectl get pods -o wide -n default --context "kind-${CLUSTER_NAME}" || true
    echo ""
    echo "=== Consumo de CPU/Memória (Metrics-Server) ==="
    kubectl top pods -n default --context "kind-${CLUSTER_NAME}" || true
}

run_test() {
    echo "🧪 Testando fluxo completo de microsserviços via Gateway..."
    curl -i -X POST http://localhost:8080/work -H "Content-Type: application/json" -d '{"origem":"teste-local"}'
    echo ""
    echo "🧪 Testando BuscaCEP..."
    curl -i http://localhost:8000/healthz || true
    echo ""
    curl -i http://localhost:8000/api/cep/01310-100 || true
    echo ""
}

run_agent() {
    echo "🤖 Executando o container do Agente Self-Healing contra o cluster local..."
    KUBECONFIG_PATH="${HOME}/.kube/config"
    TTY_FLAG=""
    if [ -t 0 ]; then
        TTY_FLAG="-it"
    else
        TTY_FLAG="-i"
    fi
    docker run --rm ${TTY_FLAG} \
      --network host \
      -v "${KUBECONFIG_PATH}:/root/.kube/config:ro" \
      -v "${INFRA_DIR}:/workspace" \
      -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
      -e GH_TOKEN="${GH_TOKEN:-}" \
      aiops-agent-runner:local
}

case "${1:-up}" in
    up)
        cluster_up "${2:-${GRAFANA_STACK_MODE:-simple}}"
        ;;
    provision)
        provision_workloads "${2:-${GRAFANA_STACK_MODE:-simple}}"
        ;;
    down)
        cluster_down
        ;;
    status)
        cluster_status
        ;;
    test)
        run_test
        ;;
    agent)
        run_agent
        ;;
    *)
        echo "Uso: $0 {up|provision|down|status|test|agent} [simple|distributed]"
        exit 1
        ;;
esac

