#!/usr/bin/env bash
set -euo pipefail

echo "========================================================"
echo "    AIOps Self-Healing Agent Runner (Local Container)   "
echo "========================================================"

export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: Não foi possível conectar ao cluster Kubernetes."
    echo "Verifique se o kubeconfig está montado corretamente no container."
    exit 1
fi

echo "✅ Conectado ao cluster Kubernetes local com sucesso!"
echo "--- Estado atual dos pods no namespace default ---"
kubectl get pods -o wide -n default || true
echo "---------------------------------------------------"

echo "🔍 Executando pre-check determinístico de incidentes..."

FOUND=false
SIGNALS=""

# 1. Checagem de Restarts
RESTARTS=$(kubectl get pods -n default -o jsonpath='{range .items[*]}{.metadata.name}{": "}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}' | awk '{for(i=2;i<=NF;i++) if($i>0) sum+=$i} END {print sum+0}')
echo "📊 Restarts acumulados nos pods: $RESTARTS"
if [ "$RESTARTS" -gt 0 ]; then
    FOUND=true
    SIGNALS="${SIGNALS}restart_count "
fi

# 2. Checagem de CPU e Memória (via Metrics-Server se disponível)
if kubectl top pods -n default >/dev/null 2>&1; then
    echo "📊 Métricas atuais de consumo (kubectl top pods):"
    kubectl top pods -n default || true
else
    echo "ℹ️ Metrics-Server inicializando métricas..."
fi

# 3. Checagem de Métricas HTTP (/metrics nos pods de app)
for pod in $(kubectl get pods -n default -l app=buscacep-api -o jsonpath='{.items[*].metadata.name}'); do
    if [ -n "$pod" ]; then
        METRICS_OUTPUT=$(kubectl exec "$pod" -n default -- curl -s http://localhost:8000/metrics 2>/dev/null || true)
        FIVEXX=$( (echo "$METRICS_OUTPUT" | grep 'http_requests_total.*status="5' || true) | awk '{sum+=$NF} END {print sum+0}')
        if [ "${FIVEXX:-0}" -gt 0 ]; then
            echo "⚠️ Detectados erros HTTP 5xx no pod $pod: $FIVEXX"
            FOUND=true
            SIGNALS="${SIGNALS}http_5xx "
        fi
    fi
done

echo "---------------------------------------------------"
if [ "$FOUND" = "true" ]; then
    echo "🚨 Sinais de anomalia detectados: ${SIGNALS}"
    
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "🤖 Acionando o agente de IA para diagnóstico..."
        TASK_FILE="/workspace/agents/log-analyzer/TASK.md"
        if [ -f "$TASK_FILE" ]; then
            TASK="$(cat "$TASK_FILE")
            
O pre-check encontrou sinal(is) de problema no cluster local em: ${SIGNALS}"
            claude -p "$TASK" \
              --allowedTools "Bash(kubectl get:*)" "Bash(kubectl describe:*)" "Bash(kubectl logs:*)" "Bash(kubectl top:*)" "Bash(gh issue create:*)" "Bash(gh issue list:*)" "Bash(gh label create:*)"
        else
            echo "⚠️ Arquivo de tarefa $TASK_FILE não encontrado."
        fi
    else
        echo "ℹ️ ANTHROPIC_API_KEY não fornecida. Diagnóstico mecânico concluído."
        echo "Para executar o agente com LLM, forneça ANTHROPIC_API_KEY e GH_TOKEN."
    fi
else
    echo "✅ Nenhum sinal de problema recente encontrado no cluster local."
fi
echo "========================================================"
