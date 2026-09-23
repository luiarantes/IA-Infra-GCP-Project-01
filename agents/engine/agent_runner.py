#!/usr/bin/env python3
"""
AIOps Agent Runner Engine
Motor agnóstico de execução para agentes de Self-Healing (Log Analyzer & PR Creator).
Suporta inferência local via Ollama (qwen2.5-coder, deepseek-r1, llama3.2) e APIs em nuvem.
Utiliza apenas a biblioteca padrão do Python (zero dependências externas / zero pip install).
"""

import os
import sys
import json
import base64
import argparse
import subprocess
import urllib.request
import urllib.parse
import urllib.error
from typing import Dict, Any, List, Optional

# Configurações padrão via variáveis de ambiente
AI_PROVIDER = os.getenv("AIOPS_AI_PROVIDER", "ollama")
OLLAMA_HOST = os.getenv("AIOPS_OLLAMA_HOST", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("AIOPS_OLLAMA_MODEL", "qwen2.5-coder:7b")
PROMETHEUS_URL = os.getenv("AIOPS_PROMETHEUS_URL", "http://localhost:5080/api/default/prometheus")
LOKI_URL = os.getenv("AIOPS_LOKI_URL", "http://localhost:3100")
LOCAL_TRACKER = os.getenv("AIOPS_LOCAL_TRACKER", "github")
AIOPS_ENV = os.getenv("AIOPS_ENV", "gcp")
WORKSPACE_DIR = os.getenv("AIOPS_WORKSPACE_DIR", os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))


class ToolRegistry:
    """Implementa as ferramentas seguras disponibilizadas ao agente."""

    @staticmethod
    def kubectl_inspect(command: str) -> str:
        """Executa comandos de leitura do Kubernetes (get, describe, logs, top)."""
        allowed_verbs = ["get", "describe", "logs", "top", "cluster-info"]
        parts = command.strip().split()
        if not parts or parts[0] not in allowed_verbs:
            return f"Erro: Apenas comandos de leitura {allowed_verbs} são permitidos via kubectl_inspect."
        try:
            full_cmd = ["kubectl"] + parts
            result = subprocess.run(full_cmd, capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                return f"Erro (código {result.returncode}): {result.stderr.strip()}"
            return result.stdout.strip() or "Nenhuma saída retornada."
        except Exception as e:
            return f"Exceção ao executar kubectl: {str(e)}"

    @staticmethod
    def query_prometheus(promql: str) -> str:
        """Consulta métricas na API padrão do Prometheus (/api/v1/query) suportada por OpenObserve, GMP e AMP."""
        params = urllib.parse.urlencode({"query": promql})
        url = f"{PROMETHEUS_URL}/api/v1/query?{params}"
        req = urllib.request.Request(url, method="GET")

        # Autenticação se for OpenObserve
        if "5080" in PROMETHEUS_URL:
            oo_user = os.getenv("AIOPS_OO_USER", "admin@example.com")
            oo_pass = os.getenv("AIOPS_OO_PASS", "ComplexPassword123#")
            creds = base64.b64encode(f"{oo_user}:{oo_pass}".encode("utf-8")).decode("utf-8")
            req.add_header("Authorization", f"Basic {creds}")

        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                if response.status != 200:
                    return f"Erro HTTP {response.status}: {response.read().decode('utf-8')}"
                data = json.loads(response.read().decode("utf-8"))
                results = data.get("data", {}).get("result", [])
                if not results:
                    return "Nenhum ponto de métrica retornado para a query."
                formatted = []
                for item in results[:10]:
                    metric = item.get("metric", {})
                    val = item.get("value", [None, None])
                    formatted.append(f"Métrica: {metric} -> Valor: {val[1]}")
                return "\n".join(formatted)
        except urllib.error.URLError as e:
            return f"Falha ao consultar Prometheus ({url}): {str(e)}"
        except Exception as e:
            return f"Exceção na consulta Prometheus: {str(e)}"

    @staticmethod
    def scrape_pod_metrics(pod_name: str, port: int = 8000, namespace: str = "apps") -> str:
        """Coleta o /metrics diretamente do pod via Kubelet Raw Proxy (zero dependência de backend)."""
        raw_path = f"/api/v1/namespaces/{namespace}/pods/{pod_name}:{port}/proxy/metrics"
        try:
            cmd = ["kubectl", "get", "--raw", raw_path]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            if result.returncode != 0:
                return f"Erro ao coletar métricas do pod {pod_name}: {result.stderr.strip()}"
            lines = [l for l in result.stdout.splitlines() if not l.startswith("#") and l.strip()]
            return "\n".join(lines[:60]) or "Nenhuma métrica encontrada."
        except Exception as e:
            return f"Exceção no Kubelet proxy: {str(e)}"

    @staticmethod
    def query_loki_logs(query: str, limit: int = 50) -> str:
        """Consulta logs estruturados no Loki (/loki/api/v1/query_range)."""
        params = urllib.parse.urlencode({"query": query, "limit": str(limit)})
        url = f"{LOKI_URL}/loki/api/v1/query_range?{params}"
        req = urllib.request.Request(url, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                if response.status != 200:
                    return f"Erro HTTP {response.status}: {response.read().decode('utf-8')}"
                data = json.loads(response.read().decode("utf-8"))
                streams = data.get("data", {}).get("result", [])
                if not streams:
                    return "Nenhum log encontrado para a query."
                logs = []
                for s in streams:
                    stream_labels = s.get("stream", {})
                    for entry in s.get("values", []):
                        line = entry[1]
                        logs.append(f"[{stream_labels.get('service_name', 'app')}] {line.strip()}")
                return "\n".join(logs[-limit:])
        except Exception as e:
            return f"Falha ao consultar Loki: {str(e)}"

    @staticmethod
    def read_file(file_path: str) -> str:
        """Lê o conteúdo de um arquivo do repositório."""
        abs_path = os.path.normpath(os.path.join(WORKSPACE_DIR, file_path))
        if not abs_path.startswith(WORKSPACE_DIR):
            return "Erro: Caminho fora do workspace permitido."
        if not os.path.exists(abs_path):
            return f"Erro: Arquivo {file_path} não encontrado."
        try:
            with open(abs_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            return f"Erro ao ler arquivo: {str(e)}"

    @staticmethod
    def apply_patch(file_path: str, new_content: str) -> str:
        """Grava o novo conteúdo em um arquivo do repositório (permitido apenas em apps/ e observability/)."""
        norm_path = os.path.normpath(file_path)
        if not (norm_path.startswith("apps/") or norm_path.startswith("observability/")):
            return "Erro: Alterações permitidas estritamente em apps/ ou observability/."
        abs_path = os.path.normpath(os.path.join(WORKSPACE_DIR, norm_path))
        try:
            os.makedirs(os.path.dirname(abs_path), exist_ok=True)
            with open(abs_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            return f"Sucesso: Arquivo {file_path} atualizado com sucesso."
        except Exception as e:
            return f"Erro ao gravar arquivo: {str(e)}"

    @staticmethod
    def _normalize_labels(labels: Any, default_label: str) -> List[str]:
        if isinstance(labels, str):
            res = [x.strip() for x in labels.split(",") if x.strip()]
        elif isinstance(labels, (list, tuple)):
            res = [str(x).strip() for x in labels if str(x).strip()]
        else:
            res = []
        if default_label and default_label not in res:
            res.append(default_label)
        if AIOPS_ENV == "local" and "env:local" not in res:
            res.append("env:local")
        return res

    @staticmethod
    def create_issue(title: str, body: str, labels: Any) -> str:
        """Cria uma GitHub Issue (ou salva em agents/findings/ se modo file/offline)."""
        norm_labels = ToolRegistry._normalize_labels(labels, "agent-finding")
        if LOCAL_TRACKER == "file":
            return ToolRegistry.create_issue_local_fallback(title, body, norm_labels, "Modo file configurado")
        try:
            for l in norm_labels:
                subprocess.run(["gh", "label", "create", l, "--force"], cwd=WORKSPACE_DIR, capture_output=True)

            cmd = ["gh", "issue", "create", "--title", title, "--body", body]
            for l in norm_labels:
                cmd.extend(["--label", l])
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=20, cwd=WORKSPACE_DIR)
            if res.returncode != 0:
                return ToolRegistry.create_issue_local_fallback(title, body, norm_labels, res.stderr)
            return f"GitHub Issue criada com sucesso: {res.stdout.strip()}"
        except Exception as e:
            return ToolRegistry.create_issue_local_fallback(title, body, norm_labels, str(e))

    @staticmethod
    def create_issue_local_fallback(title: str, body: str, labels: List[str], err: str) -> str:
        findings_dir = os.path.join(WORKSPACE_DIR, "agents/findings")
        os.makedirs(findings_dir, exist_ok=True)
        issue_id = len(os.listdir(findings_dir)) + 1
        issue_file = os.path.join(findings_dir, f"issue-{issue_id}.md")
        with open(issue_file, "w", encoding="utf-8") as f:
            f.write(f"# {title}\n\n**Labels**: {', '.join(labels)}\n\n{body}\n")
        return f"Issue registrada localmente em: {issue_file} (ID: {issue_id}). [Info: {err.strip()}]"

    @staticmethod
    def calculate_risk_score(diff_text: str, modified_files: List[str]) -> tuple:
        """Calcula um score determinístico de risco (0-100) para triagem humana do PR."""
        file_type_score = 10
        file_desc = "Manifestos declarativos (.yaml/.json)"
        if any(f.endswith(".py") for f in modified_files):
            file_type_score = 40
            file_desc = "Código-fonte executável Python (.py)"

        nature_score = 15
        nature_desc = "Configuração Geral"
        diff_lower = diff_text.lower()
        if any(term in diff_lower for term in ["resources:", "limits:", "requests:", "livenessprobe:", "readinessprobe:", "startupprobe:"]):
            nature_score = 10
            nature_desc = "Ajuste Operacional de Recursos ou Healthcheck Probes"
        elif any(term in diff_lower for term in ["env:", "command:", "args:", "volumemounts:", "volumes:", "image:"]):
            nature_score = 25
            nature_desc = "Alteração Estrutural de Runtime (Env / Volumes / Imagem)"

        service_score = 15
        service_desc = "Serviço Padrão"
        joined_files = " ".join(modified_files).lower()
        if "gateway" in joined_files:
            service_score = 25
            service_desc = "gateway (Ingress / Ponto de Entrada Crítico)"
        elif "service-api" in joined_files or "buscacep-api" in joined_files:
            service_score = 20
            service_desc = "Core API (Processamento Central)"
        elif "service-worker" in joined_files or "buscacep-worker" in joined_files:
            service_score = 15
            service_desc = "Worker Assíncrono (Fila Pub/Sub)"
        elif "service-downstream" in joined_files:
            service_score = 10
            service_desc = "Downstream Helper Service"

        diff_lines = len([l for l in diff_text.splitlines() if (l.startswith("+") or l.startswith("-")) and not (l.startswith("+++") or l.startswith("---"))])
        if diff_lines <= 10:
            diff_score = 5
            diff_desc = f"{diff_lines} linhas alteradas (Diff Mínimo)"
        elif diff_lines <= 30:
            diff_score = 15
            diff_desc = f"{diff_lines} linhas alteradas (Diff Moderado)"
        else:
            diff_score = 30
            diff_desc = f"{diff_lines} linhas alteradas (Diff Amplo)"

        total_score = min(100, file_type_score + nature_score + service_score + diff_score)

        if total_score < 30:
            risk_label = "risk:low"
            risk_badge = "🟢 Baixo Risco (risk:low)"
        elif total_score <= 60:
            risk_label = "risk:medium"
            risk_badge = "🟡 Médio Risco (risk:medium)"
        else:
            risk_label = "risk:high"
            risk_badge = "🔴 Alto Risco (risk:high)"

        report = f"""
### 🛡️ Avaliação Determinística de Risco (Blast Radius)

| Critério | Avaliação | Pontos |
| :--- | :--- | :--- |
| **Tipo de Arquivo** | {file_desc} | +{file_type_score} pts |
| **Natureza do Patch** | {nature_desc} | +{nature_score} pts |
| **Criticidade do Componente** | {service_desc} | +{service_score} pts |
| **Volume de Modificações** | {diff_desc} | +{diff_score} pts |
| **Score Total de Risco** | **{total_score} / 100** | **{risk_badge}** |

> [!NOTE]
> **Human-in-the-Loop Inviolável**: Esta pontuação é estritamente informativa para orientar a revisão. O PR requer 100% de conferência e aprovação humana antes de qualquer deploy no cluster.
"""
        return total_score, risk_label, report

    @staticmethod
    def create_git_pr(branch_name: str, commit_msg: str, pr_title: str, pr_body: str, labels: Any) -> str:
        """Cria uma branch git, commita o arquivo corrigido e abre PR com score de risco."""
        norm_labels = ToolRegistry._normalize_labels(labels, "agent-fix")
        try:
            status = subprocess.run(["git", "status", "--porcelain", "apps/", "observability/"], cwd=WORKSPACE_DIR, capture_output=True, text=True)
            if not status.stdout.strip():
                return "Erro: Nenhum arquivo foi modificado em apps/ ou observability/. Você DEVE chamar 'read_file' e depois 'apply_patch' para alterar o arquivo antes de chamar 'create_git_pr'."

            # Captura o diff para cálculo do score determinístico de risco
            diff_res = subprocess.run(["git", "diff", "apps/", "observability/"], cwd=WORKSPACE_DIR, capture_output=True, text=True)
            mod_files = [line.strip().split()[-1] for line in status.stdout.strip().splitlines() if line.strip()]
            score, risk_label, risk_report = ToolRegistry.calculate_risk_score(diff_res.stdout, mod_files)

            if risk_label not in norm_labels:
                norm_labels.append(risk_label)

            full_pr_body = f"{pr_body.strip()}\n\n{risk_report}"

            subprocess.run(["git", "checkout", "-B", branch_name], cwd=WORKSPACE_DIR, check=True, capture_output=True)
            subprocess.run(["git", "add", "apps/", "observability/"], cwd=WORKSPACE_DIR, check=True, capture_output=True)
            subprocess.run(["git", "commit", "-m", f"{commit_msg} [skip ci]"], cwd=WORKSPACE_DIR, check=True, capture_output=True)
            
            if LOCAL_TRACKER == "file":
                return f"Branch {branch_name} criada e commitada com sucesso no Git local (modo offline ativo). Score de risco: {score} ({risk_label})."

            push_res = subprocess.run(["git", "push", "-u", "origin", branch_name, "--force"], cwd=WORKSPACE_DIR, capture_output=True, text=True)
            if push_res.returncode != 0:
                return f"Branch {branch_name} commitada localmente. Push remoto indisponível: {push_res.stderr.strip()}"

            for l in norm_labels:
                subprocess.run(["gh", "label", "create", l, "--force"], cwd=WORKSPACE_DIR, capture_output=True)

            pr_cmd = ["gh", "pr", "create", "--title", pr_title, "--body", full_pr_body]
            for l in norm_labels:
                pr_cmd.extend(["--label", l])
            pr_res = subprocess.run(pr_cmd, cwd=WORKSPACE_DIR, capture_output=True, text=True)
            if pr_res.returncode != 0:
                if "already exists" in pr_res.stderr.lower():
                    return f"Branch atualizada e commit enviado para o PR existente ({branch_name}). Score de risco: {score} ({risk_label})."
                return f"Branch enviada. PR via gh retornou: {pr_res.stderr.strip()}"
            return f"Pull Request criado com sucesso: {pr_res.stdout.strip()} [Score de risco: {score} ({risk_label})]"
        except Exception as e:
            return f"Falha na automação Git/PR: {str(e)}"

    @staticmethod
    def view_issue(issue_number: int) -> str:
        """Lê o conteúdo de uma GitHub Issue ou arquivo local de finding."""
        try:
            res = subprocess.run(["gh", "issue", "view", str(issue_number)], cwd=WORKSPACE_DIR, capture_output=True, text=True, timeout=15)
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        except Exception:
            pass
        local_file = os.path.join(WORKSPACE_DIR, f"agents/findings/issue-{issue_number}.md")
        if os.path.exists(local_file):
            with open(local_file, "r", encoding="utf-8") as f:
                return f.read()
        return f"Issue #{issue_number} não encontrada."

    @staticmethod
    def view_ground_truth(file_path: str = "") -> str:
        """Lê o gabarito (Ground Truth) seguro gerado pelo injetor de caos."""
        target_path = file_path if file_path else os.path.join(WORKSPACE_DIR, "chaos-test/.ground-truth/ground-truth.json")
        if not os.path.exists(target_path):
            return "Erro: Nenhum arquivo de gabarito (ground-truth.json) encontrado. Execute o injetor de caos primeiro."
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            return f"Erro ao ler ground-truth: {str(e)}"

    @staticmethod
    def view_pull_request(pr_number: int) -> str:
        """Lê o título, descrição, labels e diff de um Pull Request para auditoria."""
        try:
            res = subprocess.run(["gh", "pr", "view", str(pr_number)], cwd=WORKSPACE_DIR, capture_output=True, text=True, timeout=15)
            diff_res = subprocess.run(["gh", "pr", "diff", str(pr_number)], cwd=WORKSPACE_DIR, capture_output=True, text=True, timeout=15)
            out = res.stdout.strip()
            if diff_res.returncode == 0 and diff_res.stdout.strip():
                out += f"\n\n--- Diff do PR #{pr_number} ---\n{diff_res.stdout.strip()}"
            return out or f"PR #{pr_number} não retornou dados."
        except Exception as e:
            return f"Erro ao consultar PR #{pr_number}: {str(e)}"

    @staticmethod
    def publish_scorecard(issue_number: int, scorecard_markdown: str) -> str:
        """Publica o Chaos Scorecard como comentário na Issue ou arquivo local de auditoria."""
        try:
            res = subprocess.run(["gh", "issue", "comment", str(issue_number), "--body", scorecard_markdown], cwd=WORKSPACE_DIR, capture_output=True, text=True)
            if res.returncode == 0:
                return f"Scorecard publicado com sucesso como comentário na Issue #{issue_number}."
        except Exception:
            pass
        out_file = os.path.join(WORKSPACE_DIR, f"agents/findings/scorecard-issue-{issue_number}.md")
        os.makedirs(os.path.dirname(out_file), exist_ok=True)
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(scorecard_markdown)
        return f"Scorecard publicado localmente em: {out_file} (Issue #{issue_number})."


TOOLS_SCHEMA = [
    {
        "name": "view_issue",
        "description": "Lê o título, corpo, labels e diagnóstico completo de uma Issue (ex: issue_number=14).",
        "parameters": {"type": "object", "properties": {"issue_number": {"type": "integer"}}, "required": ["issue_number"]}
    },
    {
        "name": "kubectl_inspect",
        "description": "Executa comandos de leitura no cluster K8s. Argumentos permitidos: get pods, describe pod <nome>, logs <nome>, top pod.",
        "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}
    },
    {
        "name": "query_prometheus",
        "description": "Consulta métricas na API Prometheus/OpenObserve via PromQL (ex: taxa de 5xx, latência, CPU).",
        "parameters": {"type": "object", "properties": {"promql": {"type": "string"}}, "required": ["promql"]}
    },
    {
        "name": "scrape_pod_metrics",
        "description": "Coleta o /metrics instantâneo do pod via Kubelet Proxy sem depender de banco de métricas.",
        "parameters": {"type": "object", "properties": {"pod_name": {"type": "string"}, "port": {"type": "integer"}, "namespace": {"type": "string"}}, "required": ["pod_name"]}
    },
    {
        "name": "query_loki_logs",
        "description": "Consulta logs estruturados no Loki com LogQL (ex: '{service_name=\"service-api\"} |= \"error\"').",
        "parameters": {"type": "object", "properties": {"query": {"type": "string"}, "limit": {"type": "integer"}}, "required": ["query"]}
    },
    {
        "name": "read_file",
        "description": "Lê o conteúdo de um arquivo do repositório (ex: 'apps/service-api/deployment.yaml').",
        "parameters": {"type": "object", "properties": {"file_path": {"type": "string"}}, "required": ["file_path"]}
    },
    {
        "name": "apply_patch",
        "description": "Aplica conteúdo corrigido em um arquivo permitido (dentro de apps/ ou observability/).",
        "parameters": {"type": "object", "properties": {"file_path": {"type": "string"}, "new_content": {"type": "string"}}, "required": ["file_path", "new_content"]}
    },
    {
        "name": "create_issue",
        "description": "Abre uma Issue formal de achado de observabilidade com título, diagnóstico e labels.",
        "parameters": {"type": "object", "properties": {"title": {"type": "string"}, "body": {"type": "string"}, "labels": {"type": "array", "items": {"type": "string"}}}, "required": ["title", "body", "labels"]}
    },
    {
        "name": "create_git_pr",
        "description": "Cria branch Git, commita o arquivo corrigido e abre um Pull Request (agent-fix).",
        "parameters": {"type": "object", "properties": {"branch_name": {"type": "string"}, "commit_msg": {"type": "string"}, "pr_title": {"type": "string"}, "pr_body": {"type": "string"}, "labels": {"type": "array", "items": {"type": "string"}}}, "required": ["branch_name", "commit_msg", "pr_title", "pr_body", "labels"]}
    },
    {
        "name": "view_ground_truth",
        "description": "Lê o gabarito oficial e parâmetros da injeção de caos (Ground Truth) para auditoria.",
        "parameters": {"type": "object", "properties": {"file_path": {"type": "string"}}, "required": []}
    },
    {
        "name": "view_pull_request",
        "description": "Lê detalhes e diff completo de um Pull Request para auditoria de patch.",
        "parameters": {"type": "object", "properties": {"pr_number": {"type": "integer"}}, "required": ["pr_number"]}
    },
    {
        "name": "publish_scorecard",
        "description": "Publica o relatório final de auditoria (Chaos Scorecard) com nota de resiliência e acurácia.",
        "parameters": {"type": "object", "properties": {"issue_number": {"type": "integer"}, "scorecard_markdown": {"type": "string"}}, "required": ["issue_number", "scorecard_markdown"]}
    }
]


def execute_tool(name: str, args: Dict[str, Any]) -> str:
    """Despacha a chamada para a ferramenta correspondente."""
    if name in ["view_issue", "gh issue view", "gh_issue_view"]:
        num = args.get("issue_number") or args.get("issue") or args.get("number", 14)
        try:
            return ToolRegistry.view_issue(int(str(num).replace("#", "")))
        except Exception:
            return ToolRegistry.view_issue(14)
    elif name == "kubectl_inspect":
        return ToolRegistry.kubectl_inspect(args.get("command", ""))
    elif name == "query_prometheus":
        return ToolRegistry.query_prometheus(args.get("promql", ""))
    elif name == "scrape_pod_metrics":
        return ToolRegistry.scrape_pod_metrics(args.get("pod_name", ""), args.get("port", 8000), args.get("namespace", "apps"))
    elif name == "query_loki_logs":
        return ToolRegistry.query_loki_logs(args.get("query", ""), args.get("limit", 50))
    elif name == "read_file":
        return ToolRegistry.read_file(args.get("file_path", ""))
    elif name == "apply_patch":
        return ToolRegistry.apply_patch(args.get("file_path", ""), args.get("new_content", ""))
    elif name == "create_issue":
        return ToolRegistry.create_issue(args.get("title", ""), args.get("body", ""), args.get("labels", []))
    elif name == "create_git_pr":
        return ToolRegistry.create_git_pr(args.get("branch_name", ""), args.get("commit_msg", ""), args.get("pr_title", ""), args.get("pr_body", ""), args.get("labels", []))
    elif name == "view_ground_truth":
        return ToolRegistry.view_ground_truth(args.get("file_path", ""))
    elif name == "view_pull_request":
        pr_num = args.get("pr_number") or args.get("pr") or args.get("number", 1)
        try:
            return ToolRegistry.view_pull_request(int(str(pr_num).replace("#", "")))
        except Exception:
            return ToolRegistry.view_pull_request(1)
    elif name == "publish_scorecard":
        issue_num = args.get("issue_number") or args.get("issue") or 1
        return ToolRegistry.publish_scorecard(int(str(issue_num).replace("#", "")), args.get("scorecard_markdown", ""))
    return f"Ferramenta desconhecida: {name}"


OLLAMA_TIMEOUT = int(os.getenv("AIOPS_OLLAMA_TIMEOUT", "300"))


def call_ollama(messages: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Chama a API do Ollama local via urllib."""
    url = f"{OLLAMA_HOST}/v1/chat/completions"
    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "temperature": 0.1,
        "stream": False,
        "keep_alive": "30m"
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT) as resp:
            if resp.status != 200:
                raise RuntimeError(f"Falha na API do Ollama ({resp.status}): {resp.read().decode('utf-8')}")
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise RuntimeError(f"Não foi possível conectar ao Ollama em {OLLAMA_HOST}. Verifique se o container está rodando ('make local-aiops-ollama-up'). Detalhe: {e}")


def run_agent_loop(role: str, system_prompt: str, user_instruction: str, max_turns: int = 10) -> str:
    """Executa o loop ReAct do agente interagindo com o modelo de IA."""
    role_tool_names = {
        "log-analyzer": ["kubectl_inspect", "query_prometheus", "scrape_pod_metrics", "query_loki_logs", "create_issue"],
        "pr-creator": ["view_issue", "read_file", "apply_patch", "create_git_pr"],
        "evaluator": ["view_ground_truth", "view_issue", "view_pull_request", "read_file", "publish_scorecard"]
    }.get(role, [t["name"] for t in TOOLS_SCHEMA])

    active_tools = [t for t in TOOLS_SCHEMA if t["name"] in role_tool_names]

    tools_prompt = f"""
Você tem acesso às seguintes ferramentas técnicas de infraestrutura e observabilidade:
{json.dumps(active_tools, indent=2, ensure_ascii=False)}

Para executar uma ferramenta técnica, responda com um bloco JSON EXATAMENTE neste formato:
```json
{{
  "tool": "nome_da_ferramenta",
  "arguments": {{ "param1": "valor" }}
}}
```
Importante: execute primeiro as ferramentas de inspeção necessárias para diagnosticar a causa-raiz com dados reais. Ao concluir o diagnóstico, chame 'create_issue' (para log-analyzer), 'create_git_pr' (para pr-creator) ou 'publish_scorecard' (para evaluator).
"""
    messages = [
        {"role": "system", "content": system_prompt + "\n\n" + tools_prompt},
        {"role": "user", "content": user_instruction}
    ]

    print(f"🤖 Iniciando Agente AIOps [{role} | Modelo: {OLLAMA_MODEL} via {AI_PROVIDER}]...")
    tool_call_history: List[str] = []

    for turn in range(1, max_turns + 1):
        print(f"\n--- [Turno {turn}/{max_turns}] Consultando Modelo ---")
        response = call_ollama(messages)
        content = response["choices"][0]["message"]["content"]
        messages.append({"role": "assistant", "content": content})
        print(f"Resposta do Modelo:\n{content}\n")

        # Procura chamada de ferramenta no output (robusto a ```json, ``` ou JSON puro)
        tool_call = None
        import re
        json_match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", content, re.DOTALL)
        if json_match:
            try:
                parsed = json.loads(json_match.group(1))
                if "tool" in parsed:
                    tool_call = parsed
            except Exception:
                pass

        if not tool_call:
            # Fallback para busca de objeto JSON puro contendo "tool"
            raw_match = re.search(r'(\{\s*"tool"\s*:\s*"[^"]+".*?\})', content, re.DOTALL)
            if raw_match:
                try:
                    parsed = json.loads(raw_match.group(1))
                    if "tool" in parsed:
                        tool_call = parsed
                except Exception:
                    pass

        if not tool_call:
            print("✅ Agente finalizou a execução.")
            return content

        tool_name = tool_call.get("tool")
        tool_args = tool_call.get("arguments", {})
        print(f"⚡ Executando ferramenta: {tool_name} com {tool_args}")
        obs = execute_tool(tool_name, tool_args)
        print(f"📊 Observação retornada ({len(obs)} caracteres):\n{obs[:400]}...")

        # Ações terminais: encerram o ciclo apenas se concluídas com sucesso real
        if tool_name == "create_issue" and ("Issue" in obs) and ("Falha" not in obs and "Erro" not in obs):
            print(f"🎯 Ação terminal '{tool_name}' concluída com sucesso! Encerrando ciclo do agente.")
            return obs
        if tool_name == "create_git_pr" and ("Pull Request criado" in obs or "Branch" in obs) and ("Falha" not in obs and "Erro" not in obs):
            print(f"🎯 Ação terminal '{tool_name}' concluída com sucesso! Encerrando ciclo do agente.")
            return obs
        if tool_name == "publish_scorecard" and ("Scorecard" in obs) and ("Falha" not in obs and "Erro" not in obs):
            print(f"🎯 Ação terminal '{tool_name}' concluída com sucesso! Encerrando ciclo do agente.")
            return obs

        # Prevenção de loops e orientação de progresso para modelos menores
        tool_call_sig = f"{tool_name}:{json.dumps(tool_args, sort_keys=True)}"
        if tool_call_history.count(tool_call_sig) >= 1:
            if role == "log-analyzer":
                obs += "\n\n⚠️ ATENÇÃO: Você repetiu a mesma chamada de ferramenta anterior. Você já possui evidências suficientes. Formule agora sua conclusão e chame a ferramenta 'create_issue' com title, body detalhado (RCA) e labels."
            elif role == "pr-creator":
                obs += "\n\n⚠️ ATENÇÃO: Chamada repetida. Se os arquivos já foram lidos, aplique a correção via 'apply_patch' e crie o Pull Request com 'create_git_pr'."
        elif role == "log-analyzer" and turn >= 3:
            obs += "\n\n[ORIENTAÇÃO]: Dados de diagnóstico e inspeção foram coletados com sucesso. Prossiga para abrir a Issue de achado chamando a ferramenta 'create_issue' (com title, body contendo RCA e labels)."
        tool_call_history.append(tool_call_sig)

        messages.append({
            "role": "user",
            "content": f"Observation from {tool_name}:\n{obs}"
        })

    return "Atingido limite de turnos de execução."


def main():
    parser = argparse.ArgumentParser(description="AIOps Agent Runner")
    parser.add_argument("--role", choices=["log-analyzer", "pr-creator", "evaluator"], required=True, help="Papel do agente")
    parser.add_argument("--task-file", help="Caminho para o TASK.md")
    parser.add_argument("--context", default="", help="Contexto operacional (sinais ou número da issue)")
    parser.add_argument("--app", default="", help="Foco em um microsserviço específico (opcional)")
    parser.add_argument("--hint", default="", help="Pista, contexto ou hipótese do operador humano (opcional)")
    parser.add_argument("--force", action="store_true", help="Força investigação ignorando pre-check de métricas")
    args = parser.parse_args()

    task_content = ""
    if args.task_file and os.path.exists(args.task_file):
        with open(args.task_file, "r", encoding="utf-8") as f:
            task_content = f.read()

    enriched_context = args.context
    if args.app:
        enriched_context += f" | Foco investigativo direcionado ao componente: '{args.app}'"
    if args.hint:
        enriched_context += f" | Pista fornecida pelo operador humano: '{args.hint}'"
    if args.force:
        enriched_context += " | Modo: Forçado manualmente por operador (Modo Laboratório/Treinamento)"

    system_prompt = f"Você é o Agente de AIOps ({args.role}).\n{task_content}"
    if args.role == "log-analyzer":
        user_instruction = (
            f"Inicie a execução da sua tarefa investigando o cluster.\n"
            f"Contexto informado: {enriched_context}\n"
            f"OBRIGATÓRIO: Responda imediatamente chamando uma ferramenta técnica em JSON (ex: 'kubectl_inspect' com 'get pods -o wide') para inspecionar os pods e métricas antes de tirar conclusões."
        )
    elif args.role == "pr-creator":
        user_instruction = (
            f"Inicie a execução da sua tarefa para propor a correção (PR).\n"
            f"Contexto informado: {enriched_context}\n"
            f"OBRIGATÓRIO: Siga rigorosamente este fluxo passo a passo:\n"
            f"Passo 1: Chame 'view_issue' para ler o diagnóstico detalhado da issue.\n"
            f"Passo 2: Chame 'read_file' no manifesto relevante (ex: 'apps/service-api/deployment.yaml').\n"
            f"Passo 3: Chame 'apply_patch' para gravar o arquivo com a correção cirúrgica (ex: corrigindo o livenessProbe para '/healthz').\n"
            f"Passo 4: Somente após 'apply_patch' ter sucesso, chame 'create_git_pr' com branch_name, commit_msg, pr_title, pr_body e labels=['agent-fix', 'signal:restart_count', 'app:service-api'].\n"
            f"Inicie agora executando o Passo 1 com 'view_issue'."
        )
    elif args.role == "evaluator":
        user_instruction = (
            f"Inicie a execução da sua tarefa como Agente Avaliador Autônomo (Evaluator Agent).\n"
            f"Contexto informado: {enriched_context}\n"
            f"OBRIGATÓRIO: Siga rigorosamente este fluxo passo a passo:\n"
            f"Passo 1: Chame 'view_ground_truth' para ler o gabarito oficial da injeção de caos.\n"
            f"Passo 2: Chame 'view_issue' para ler o diagnóstico reportado pelo log-analyzer.\n"
            f"Passo 3: Opcionalmente chame 'view_pull_request' para avaliar a qualidade e o raio de explosão do patch proposto.\n"
            f"Passo 4: Compare a causa-raiz identificada com o gabarito oficial e calcule a Acurácia de Causa-Raiz (RCA Accuracy: 0-100%).\n"
            f"Passo 5: Formate o relatório Markdown do Chaos Scorecard e chame 'publish_scorecard' com a nota final de resiliência.\n"
            f"Inicie agora executando o Passo 1 com 'view_ground_truth'."
        )
    else:
        user_instruction = f"Inicie a execução da sua tarefa de forma autônoma.\nContexto informado: {enriched_context}"

    run_agent_loop(args.role, system_prompt, user_instruction)


if __name__ == "__main__":
    main()
