#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "========================================================="
echo "    AIOps Agente 2: PR & Fix Creator (Local)             "
echo "========================================================="

ISSUE_NUM=""
OPERATOR_HINT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue)
            ISSUE_NUM="$2"
            shift 2
            ;;
        --hint|--instruction)
            OPERATOR_HINT="$2"
            shift 2
            ;;
        *)
            if [ -z "$ISSUE_NUM" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
                ISSUE_NUM="$1"
                shift
            else
                echo "Opção desconhecida: $1"
                echo "Uso: $0 [<numero-da-issue>] [--hint \"instrução adicional\"]"
                exit 1
            fi
            ;;
    esac
done

if [ -z "$ISSUE_NUM" ]; then
    ISSUE_NUM="${ISSUE:-}"
fi

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
    echo "Dica: Você pode informar manualmente via: ./agents/pr-creator/create-pr-local.sh <numero-da-issue> [--hint <instrução>]"
    exit 0
fi

echo "📋 Atuando sobre a Issue #${ISSUE_NUM}..."
ISSUE_CONTENT=$(gh issue view "$ISSUE_NUM" 2>/dev/null || cat "${WORKSPACE_DIR}/agents/findings/issue-${ISSUE_NUM}.md" 2>/dev/null || echo "Issue #${ISSUE_NUM}")

echo "🤖 Acionando o modelo de IA para analisar o código e gerar a proposta de correção..."

EXTRA_ARGS=()
if [ -n "$OPERATOR_HINT" ]; then
    EXTRA_ARGS+=(--hint "$OPERATOR_HINT")
fi

python3 "${WORKSPACE_DIR}/agents/engine/agent_runner.py" \
    --role "pr-creator" \
    --task-file "${WORKSPACE_DIR}/agents/pr-creator/TASK.md" \
    --context "Diagnóstico reportado na Issue #${ISSUE_NUM}:
${ISSUE_CONTENT}

Analise os manifestos em apps/ com 'read_file', aplique a correção cirúrgica com 'apply_patch' e crie o Pull Request com 'create_git_pr' (branch: agent-fix/issue-${ISSUE_NUM})." \
    "${EXTRA_ARGS[@]}"

echo "========================================================="
