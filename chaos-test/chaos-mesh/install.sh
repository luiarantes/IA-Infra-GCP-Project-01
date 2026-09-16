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

echo "🚀 Instalando / Atualizando Chaos Mesh no namespace 'chaos-mesh'..."
helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh \
    --namespace chaos-mesh \
    --create-namespace \
    --set chaosDaemon.runtime=containerd \
    --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
    --set dashboard.create=true \
    --set dashboard.securityMode=false \
    --wait --timeout 300s

echo "✅ Chaos Mesh instalado com sucesso!"
echo ""
echo "Status dos pods no namespace chaos-mesh:"
kubectl get pods -n chaos-mesh
echo "========================================================="
