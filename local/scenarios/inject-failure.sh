#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SCENARIO="${1:-probe-crash}"

echo "========================================================="
echo "    AIOps Chaos Injection: Injetando Anomalia Controlada "
echo "========================================================="

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: Não foi possível conectar ao cluster local (Kind)."
    exit 1
fi

case "$SCENARIO" in
    probe-crash)
        echo "💥 Cenário: Injetando falha de Liveness Probe em 'service-api'..."
        echo "Alterando liveness probe para path inexistente '/healthz-invalid' na porta 8000..."
        
        # Patch direto no deployment em execução
        kubectl patch deployment service-api --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path", "value": "/healthz-invalid"},{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/periodSeconds", "value": 5}]'
        
        echo "⏳ Aguardando Kubelet detectar falha de probe e reiniciar container..."
        sleep 20
        echo "📊 Estado atual do pod:"
        kubectl get pods -l app=service-api -n default
        ;;

    oom-kill)
        echo "💥 Cenário: Injetando limite de memória insuficiente em 'service-api'..."
        echo "Reduzindo limit de memória para 16Mi (causa OOMKilled no startup do Python)..."
        
        kubectl set resources deployment/service-api --limits=memory=16Mi,cpu=200m --requests=memory=16Mi,cpu=100m
        
        echo "⏳ Aguardando container ser morto pelo OOM Killer (Exit Code 137)..."
        sleep 20
        echo "📊 Estado atual do pod:"
        kubectl get pods -l app=service-api -n default
        ;;

    restore)
        echo "🧹 Restaurando deployment 'service-api' para a configuração original saudável..."
        kubectl apply -f "${WORKSPACE_DIR}/apps/service-api/deployment.yaml"
        kubectl rollout status deployment/service-api --timeout=60s
        echo "✅ 'service-api' restaurado com sucesso!"
        ;;

    *)
        echo "Uso: $0 {probe-crash|oom-kill|restore}"
        exit 1
        ;;
esac

echo "========================================================="
