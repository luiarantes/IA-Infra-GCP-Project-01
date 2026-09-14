#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "========================================================="
echo "    AIOps Agente 1: Log & Metrics Analyzer (Local)       "
echo "========================================================="

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: Não foi possível conectar ao cluster Kubernetes local (Kind)."
    echo "Certifique-se de que o cluster está de pé com 'make local-up-simple' ou 'make local-up-distributed'."
    exit 1
fi

echo "🔍 Executando pre-check determinístico (sem custo de IA)..."

FOUND=false
SIGNALS=""

# 1. Checagem de Restarts de Pods
RESTARTS=$(kubectl get pods -n default -o jsonpath='{range .items[*]}{.metadata.name}{": "}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}' | awk '{for(i=2;i<=NF;i++) if($i>0) sum+=$i} END {print sum+0}')
echo "📊 Restarts acumulados nos pods: ${RESTARTS:-0}"
if [ "${RESTARTS:-0}" -gt 0 ]; then
    FOUND=true
    SIGNALS="${SIGNALS}restart_count "
fi

# 2. Checagem de Pods em estado anômalo (CrashLoopBackOff, Error, OOMKilled)
ANOMALOUS_PODS=$(kubectl get pods -n default --no-headers | grep -E 'CrashLoopBackOff|Error|OOMKilled' | awk '{print $1}' || true)
if [ -n "$ANOMALOUS_PODS" ]; then
    echo "⚠️ Pods em estado anômalo detectados: $ANOMALOUS_PODS"
    FOUND=true
    SIGNALS="${SIGNALS}pod_failure "
fi

# 3. Checagem de Métricas de 5xx via Prometheus API do OpenObserve
OO_URL="${AIOPS_PROMETHEUS_URL:-http://localhost:5080/api/default/prometheus}"
FIVEXX_RATE=$(curl -s -u "admin@example.com:ComplexPassword123#" -G "${OO_URL}/api/v1/query" \
    --data-urlencode 'query=sum(rate(http_requests_total{status=~"5.."}[5m]))' 2>/dev/null \
    | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")

echo "📊 Taxa de erros HTTP 5xx (PromQL): ${FIVEXX_RATE}"
if (( $(echo "${FIVEXX_RATE:-0} > 0" | bc -l 2>/dev/null || [ "${FIVEXX_RATE:-0}" != "0" ]) )); then
    FOUND=true
    SIGNALS="${SIGNALS}http_5xx "
fi

# 4. Checagem de Logs de Erro/Panic recentes no Loki
LOKI_URL="${AIOPS_LOKI_URL:-http://localhost:3100}"
LOKI_ERRORS=$(curl -s -G "${LOKI_URL}/loki/api/v1/query_range" \
    --data-urlencode 'query={namespace="default"} |= "error" or {namespace="default"} |= "panic"' \
    --data-urlencode 'limit=10' 2>/dev/null \
    | jq '.data.result | length' 2>/dev/null || echo "0")

echo "📊 Ocorrências de erros críticos recentes no Loki: ${LOKI_ERRORS:-0}"
if [ "${LOKI_ERRORS:-0}" -gt 0 ]; then
    FOUND=true
    SIGNALS="${SIGNALS}loki_errors "
fi

echo "---------------------------------------------------------"
if [ "$FOUND" = "true" ]; then
    echo "🚨 Sinais de anomalia identificados pelo pre-check: ${SIGNALS}"
    echo "🤖 Acionando o modelo de IA para investigação e diagnóstico..."
    
    python3 "${WORKSPACE_DIR}/agents/engine/agent_runner.py" \
        --role "log-analyzer" \
        --task-file "${WORKSPACE_DIR}/agents/log-analyzer/TASK.md" \
        --context "O pre-check detectou o(s) seguinte(s) sinal(is) no cluster local: ${SIGNALS}"
else
    echo "✅ Nenhum sinal de anomalia recente no cluster. IA não acionada (consumo zero de recursos)."
fi
echo "========================================================="
