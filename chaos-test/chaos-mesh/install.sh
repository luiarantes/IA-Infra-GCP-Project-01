#!/usr/bin/env bash
# =============================================================================
# Script de Instalação do Chaos Mesh (CNCF Incubating)
# Suporta clusters GKE Standard e Kind local com runtime containerd.
# =============================================================================
set -euo pipefail

echo "========================================================="
echo "    🌪️  Instalação do Chaos Mesh no Kubernetes          "
echo "========================================================="

if ! command -v helm >/dev/null 2>&1; then
    echo "❌ Helm não encontrado no sistema. Instale o helm para prosseguir."
    exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Cluster Kubernetes inacessível. Verifique seu kubeconfig."
    exit 1
fi

echo "📦 Adicionando repositório do Chaos Mesh no Helm..."
helm repo add chaos-mesh https://charts.chaos-mesh.org 2>/dev/null || true
helm repo update chaos-mesh

CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")

if echo "${CURRENT_CONTEXT}" | grep -qiE "kind|local"; then
    echo "💻 Ambiente Local (Kind) detectado."
    echo "🔌 Configurando Chaos Dashboard como NodePort na porta 32333 (hostPort 2333 no host)..."
    SERVICE_FLAGS="--set dashboard.service.type=NodePort --set dashboard.service.nodePort=32333"
    EXPECTED_URL="http://localhost:2333"
else
    echo "☁️ Ambiente Nuvem (GCP / GKE) detectado."
    echo "🌐 Configurando Chaos Dashboard como LoadBalancer (IP público sem port-forward)..."
    SERVICE_FLAGS="--set dashboard.service.type=LoadBalancer"
    EXPECTED_URL="http://<alocando-ip-publico>:2333"
fi

echo "🚀 Instalando / Atualizando Chaos Mesh no namespace 'chaos-mesh'..."
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
    --namespace chaos-mesh \
    --create-namespace \
    --set chaosDaemon.runtime=containerd \
    --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
    --set dashboard.create=true \
    --set dashboard.securityMode=false \
    ${SERVICE_FLAGS} \
    --wait --timeout 300s

echo "✅ Chaos Mesh instalado com sucesso!"
echo ""
echo "Status dos pods no namespace chaos-mesh:"
kubectl get pods -n chaos-mesh
echo ""
echo "========================================================="
if echo "${CURRENT_CONTEXT}" | grep -qiE "kind|local"; then
    echo " 🎉 Chaos Dashboard Web UI disponível em: ${EXPECTED_URL}"
else
    echo "⏳ Aguardando IP externo do LoadBalancer para o Chaos Dashboard..."
    CHAOS_IP=""
    for i in {1..20}; do
        CHAOS_IP=$(kubectl get svc chaos-dashboard -n chaos-mesh -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$CHAOS_IP" ]; then
            break
        fi
        sleep 5
    done
    if [ -n "$CHAOS_IP" ]; then
        echo " 🎉 Chaos Dashboard Web UI: http://${CHAOS_IP}:2333"
    else
        echo " ℹ️ IP do LoadBalancer pendente. Consulte com: kubectl get svc chaos-dashboard -n chaos-mesh"
    fi
fi
echo "========================================================="
