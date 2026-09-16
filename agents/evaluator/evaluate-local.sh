#!/usr/bin/env bash
# =============================================================================
# AIOps Evaluator Agent (Execução Local / CLI)
# Executa a auditoria de acurácia de RCA e qualidade de patch pós-incidente.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "========================================================="
echo "    🏆 AIOps Agente 4: Evaluator & Chaos Scorecard      "
echo "========================================================="

ISSUE_NUM=""
PR_NUM=""
GT_FILE="${WORKSPACE_DIR}/chaos-test/.ground-truth/ground-truth.json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue)
            ISSUE_NUM="$2"
            shift 2
            ;;
        --pr)
            PR_NUM="$2"
            shift 2
            ;;
        --ground-truth)
            GT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Uso: $0 [--issue <numero>] [--pr <numero>] [--ground-truth <caminho>]"
            exit 0
            ;;
        *)
            if [ -z "$ISSUE_NUM" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                ISSUE_NUM="$1"
                shift
            else
                echo "Opção desconhecida: $1"
                echo "Uso: $0 [--issue <numero>] [--pr <numero>] [--ground-truth <caminho>]"
                exit 1
            fi
            ;;
    esac
done

if [ ! -f "$GT_FILE" ]; then
    echo "⚠️ Arquivo de Ground Truth não encontrado em: $GT_FILE"
    echo "Execute um experimento de caos antes da avaliação (ex: python3 chaos-test/chaos_randomizer.py)"
    exit 1
fi

if [ -z "$ISSUE_NUM" ]; then
    echo "🔍 Identificando issue mais recente do incidente..."
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        ISSUE_NUM=$(gh issue list --label "agent-finding" --limit 1 --json number --jq '.[0].number' 2>/dev/null || echo "")
    fi
    if [ -z "$ISSUE_NUM" ]; then
        LATEST_LOCAL=$(ls -v "${WORKSPACE_DIR}/agents/findings"/issue-*.md 2>/dev/null | tail -n 1 || true)
        if [ -n "$LATEST_LOCAL" ]; then
            ISSUE_NUM=$(basename "$LATEST_LOCAL" | grep -o '[0-9]\+')
        fi
    fi
fi

if [ -z "$ISSUE_NUM" ]; then
    echo "❌ Nenhuma Issue identificada para auditar."
    exit 1
fi

echo "📋 Auditando Incidente vinculado à Issue #${ISSUE_NUM}..."
echo "📄 Gabarito utilizado: ${GT_FILE}"

python3 "${WORKSPACE_DIR}/agents/engine/agent_runner.py" \
    --role "evaluator" \
    --task-file "${WORKSPACE_DIR}/agents/evaluator/TASK.md" \
    --context "Auditoria de Resiliência: Gabarito oficial em '${GT_FILE}'. Issue alvo para auditoria de diagnóstico: #${ISSUE_NUM}. PR associado (se houver): #${PR_NUM:-desconhecido}."

echo "========================================================="
