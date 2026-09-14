#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "========================================================="
echo "    AIOps Agente 2: PR & Fix Creator (Local)             "
echo "========================================================="

ISSUE_NUM="${1:-${ISSUE:-}}"

if [ -z "$ISSUE_NUM" ]; then
    echo "🔍 Procurando achados pendentes com label 'agent-finding'..."
    # Tenta obter via gh primeiro
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        ISSUE_NUM=$(gh issue list --label "agent-finding" --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || echo "")
    fi

    # Se não encontrou via gh, busca em agents/findings local
    if [ -z "$ISSUE_NUM" ]; then
        LATEST_LOCAL=$(ls -v "${WORKSPACE_DIR}/agents/findings"/issue-*.md 2>/dev/null | tail -n 1 || true)
        if [ -n "$LATEST_LOCAL" ]; then
            ISSUE_NUM=$(basename "$LATEST_LOCAL" | grep -o '[0-9]\+')
            echo "📁 Encontrado achado local: $LATEST_LOCAL (Issue #$ISSUE_NUM)"
        fi
    fi
fi

if [ -z "$ISSUE_NUM" ]; then
    echo "ℹ️ Nenhuma Issue com label 'agent-finding' encontrada para atuar."
    echo "Dica: Você pode informar manualmente via: ./agents/pr-creator/create-pr-local.sh <numero-da-issue>"
    exit 0
fi

echo "📋 Atuando sobre a Issue #${ISSUE_NUM}..."
echo "🤖 Acionando o modelo de IA para analisar o código e gerar a proposta de correção..."

python3 "${WORKSPACE_DIR}/agents/engine/agent_runner.py" \
    --role "pr-creator" \
    --task-file "${WORKSPACE_DIR}/agents/pr-creator/TASK.md" \
    --context "Avalie o diagnóstico da Issue #${ISSUE_NUM} e proponha a correção de código/manifest mínima necessária."

echo "========================================================="
