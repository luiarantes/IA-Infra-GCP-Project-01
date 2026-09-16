#!/usr/bin/env bash
# =============================================================================
# AIOps Troubleshooting CLI (Modo Laboratório & Treinamento)
# Utilitário unificado para operadores e desenvolvedores exercitarem
# investigação, diagnóstico e geração de correções com IA.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    cat <<EOF
=============================================================================
             🛠️  AIOps Troubleshooting & Lab CLI (tshoot.sh)
=============================================================================
Uso:
  ./scripts/tshoot.sh <comando> [opções]

Comandos Disponíveis:
  analyze   Executa o Agente 1 (Log & Metrics Analyzer) com pre-check ou forçado
  fix       Executa o Agente 2 (PR & Fix Creator) sobre uma issue de finding
  evaluate  Executa o Agente 4 (Evaluator Agent) para emitir o Chaos Scorecard
  status    Verifica o estado dos componentes de observabilidade e inferência local
  chaos     Injeta um cenário de caos (Chaos Mesh ou local) sorteado ou específico
  help      Exibe esta mensagem de ajuda

Opções para 'analyze':
  --force               Ignora o pre-check de métricas e força a IA a investigar
  --app <nome>          Direciona a investigação para um microsserviço (ex: service-api)
  --hint "<texto>"      Fornece uma hipótese ou pista do operador para o agente avaliar

Opções para 'fix':
  --issue <numero>      Número da issue a ser corrigida (padrão: pega a última aberta)
  --hint "<texto>"      Instrução específica ou restrição do operador para o patch

Opções para 'evaluate':
  --issue <numero>      Número da issue de diagnóstico para auditar
  --pr <numero>         Número do PR de fix para auditar
  --ground-truth <path> Caminho para o gabarito oficial (default: chaos-test/.ground-truth/ground-truth.json)

Opções para 'chaos':
  [random | latency-downstream | cascading-5xx | cpu-throttling | slow-oom | pod-kill | clean | status]

Exemplos:
  ./scripts/tshoot.sh status
  ./scripts/tshoot.sh chaos random
  ./scripts/tshoot.sh analyze --force --app service-api --hint "Lentidão nas conexões"
  ./scripts/tshoot.sh fix --issue 12 --hint "Ajustar apenas o limits.memory para 256Mi"
  ./scripts/tshoot.sh evaluate --issue 12
=============================================================================
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    status)
        echo "🔍 Verificando estado dos componentes da stack..."
        echo ""
        echo "1. Cluster Kubernetes:"
        if kubectl cluster-info >/dev/null 2>&1; then
            kubectl get pods -n default
        else
            echo "   ❌ Não foi possível conectar ao cluster Kubernetes."
        fi
        echo ""
        echo "2. Motor Ollama Local:"
        if curl -s http://localhost:11434/api/version >/dev/null 2>&1; then
            echo "   ✅ Ollama online em http://localhost:11434 (Versão: $(curl -s http://localhost:11434/api/version | jq -r .version 2>/dev/null || echo 'OK'))"
            echo "   Modelos disponíveis:"
            curl -s http://localhost:11434/api/tags | jq -r '.models[]?.name' 2>/dev/null || echo "   (nenhum modelo listado)"
        else
            echo "   ⚠️ Ollama offline. Inicie com: make local-aiops-ollama-up"
        fi
        echo ""
        echo "3. OpenObserve:"
        if curl -s http://localhost:5080/api/version >/dev/null 2>&1; then
            echo "   ✅ OpenObserve online em http://localhost:5080"
        else
            echo "   ⚠️ OpenObserve não respondeu em http://localhost:5080"
        fi
        ;;

    analyze)
        chmod +x "${WORKSPACE_DIR}/agents/log-analyzer/analyze-local.sh"
        "${WORKSPACE_DIR}/agents/log-analyzer/analyze-local.sh" "$@"
        ;;

    fix)
        chmod +x "${WORKSPACE_DIR}/agents/pr-creator/create-pr-local.sh"
        "${WORKSPACE_DIR}/agents/pr-creator/create-pr-local.sh" "$@"
        ;;

    evaluate)
        chmod +x "${WORKSPACE_DIR}/agents/evaluator/evaluate-local.sh"
        "${WORKSPACE_DIR}/agents/evaluator/evaluate-local.sh" "$@"
        ;;

    chaos)
        SCENARIO="${1:-random}"
        ACTION="apply"
        if [ "$SCENARIO" = "clean" ]; then
            ACTION="clean"
        elif [ "$SCENARIO" = "status" ]; then
            ACTION="status"
        fi
        python3 "${WORKSPACE_DIR}/chaos-test/chaos_randomizer.py" --scenario "$SCENARIO" --action "$ACTION"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "Comando desconhecido: $cmd"
        echo ""
        usage
        exit 1
        ;;
esac
