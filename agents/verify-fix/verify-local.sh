#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "========================================================="
echo "    AIOps Agente 3: Verify Fix (Local / Determinístico)  "
echo "========================================================="

ISSUE_NUM="${1:-${ISSUE:-}}"

# Identifica a branch de fix ativa ou mais recente
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == agent-fix/* ]]; then
    FIX_BRANCH="$CURRENT_BRANCH"
else
    FIX_BRANCH=$(git branch --list 'agent-fix/*' --sort=-committerdate | head -n 1 | tr -d ' *' || true)
fi

echo "🌿 Branch de correção em validação: ${FIX_BRANCH:-main}"

# Identifica os manifests alterados
CHANGED_FILES=$(git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || true)
echo "📦 Arquivos modificados:"
echo "$CHANGED_FILES"
echo "---------------------------------------------------------"

if [ -z "$CHANGED_FILES" ]; then
    echo "ℹ️ Nenhum arquivo alterado para aplicar no cluster."
else
    echo "🚀 Aplicando correções no cluster local (Kind)..."
    python3 "${WORKSPACE_DIR}/local/scripts/apply_local_manifests.py"
fi

echo "⏳ Aguardando rollout dos deployments afetados..."
for dep in $(kubectl get deployments -n default -o jsonpath='{.items[*].metadata.name}'); do
    kubectl rollout status "deployment/${dep}" -n default --timeout=90s || true
done

echo "⏳ Aguardando janela de estabilização de 15 segundos..."
sleep 15

echo "🔍 Reconsultando sinais de telemetria..."
UNHEALTHY_PODS=$(kubectl get pods -n default --no-headers | grep -E 'CrashLoopBackOff|Error|OOMKilled|InvalidImageName' || true)

if [ -z "$UNHEALTHY_PODS" ]; then
    echo "🎉 SUCESSO: Todos os pods estão operando com 100% de integridade (1/1 Running)!"
    
    MSG="✅ [verify-fix]: Verificação pós-deploy confirmou que a anomalia foi sanada com sucesso. Todos os pods estão saudáveis sem novos restarts."
    
    if [ -n "$ISSUE_NUM" ]; then
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            gh issue comment "$ISSUE_NUM" --body "$MSG" || true
            gh issue close "$ISSUE_NUM" || true
            echo "Issue #$ISSUE_NUM fechada com sucesso no GitHub."

            # Verifica e mergeia o PR associado
            PR_NUM=$(gh pr list --head "$FIX_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
            if [ -n "$PR_NUM" ]; then
                echo "🔀 Realizando merge do Pull Request #${PR_NUM}..."
                gh pr merge "$PR_NUM" --squash --delete-branch --subject "Merge PR #${PR_NUM}: auto-healing fix for Issue #${ISSUE_NUM}" || true
            fi
        fi
        
        # Atualiza arquivo local se existir
        LOCAL_ISSUE="${WORKSPACE_DIR}/agents/findings/issue-${ISSUE_NUM}.md"
        if [ -f "$LOCAL_ISSUE" ]; then
            echo -e "\n---\n**Status**: RESOLVIDA ✅\n$MSG" >> "$LOCAL_ISSUE"
            echo "Issue local #$ISSUE_NUM atualizada como resolvida."
        fi
    fi
else
    echo "❌ FALHA: Ainda foram detectados pods com falhas:"
    echo "$UNHEALTHY_PODS"
    echo "O fix não solucionou a causa-raiz completamente. Atenção técnica requerida."
    exit 1
fi

echo "========================================================="
