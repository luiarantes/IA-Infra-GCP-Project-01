#!/usr/bin/env python3
"""
sync_control_panel.py - Sincronizador dinâmico do Painel de Controle AIOps.

Detecta o ambiente ativo (Kind Local ou GCP GKE), inspeciona portas locais
e IPs externos de Load Balancers, e atualiza atomicamente links.json e data.js.
Também permite exportar resumos em Markdown para o terminal ou GitHub Actions ($GITHUB_STEP_SUMMARY).
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

INFRA_DIR = Path(__file__).resolve().parent.parent
CONTROL_PANEL_DIR = INFRA_DIR / "control-panel"
LINKS_JSON_PATH = CONTROL_PANEL_DIR / "links.json"
DATA_JS_PATH = CONTROL_PANEL_DIR / "data.js"
KIND_CONFIG_PATH = INFRA_DIR / "local" / "kind-config.yaml"
LOCAL_TFVARS_PATH = INFRA_DIR / "infra" / "environments" / "local" / "terraform.tfvars"
LOCAL_VARS_PATH = INFRA_DIR / "infra" / "environments" / "local" / "variables.tf"
REPORTS_DIR = INFRA_DIR / "load-test" / "reports"
LEGACY_REPORT_PATH = INFRA_DIR / "load-test" / "report.html"


def run_cmd(cmd_list, timeout=10):
    """Executa um comando de forma segura com timeout."""
    try:
        res = subprocess.run(
            cmd_list,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )
        return res.returncode, res.stdout.strip()
    except Exception as exc:
        return 1, str(exc)


def detect_active_env():
    """Detecta automaticamente o ambiente ativo a partir do contexto do kubectl."""
    code, out = run_cmd(["kubectl", "config", "current-context"])
    if code == 0 and out:
        context = out.lower()
        if "gke" in context or "ia-infra" in context:
            return "gcp"
        if "kind" in context or "local" in context:
            return "local"
    return "local"


def parse_local_ports_from_kind_config():
    """Lê mapeamentos de hostPort no kind-config.yaml."""
    ports = {}
    if not KIND_CONFIG_PATH.exists():
        return ports

    try:
        content = KIND_CONFIG_PATH.read_text(encoding="utf-8")
        # Procura por blocos de hostPort com comentários associados
        matches = re.findall(
            r"(?:#\s*([^\n]+)\n\s*)?- containerPort:\s*(\d+)\s*\n\s*hostPort:\s*(\d+)",
            content,
        )
        for comment, cport, hport in matches:
            comment_lower = comment.lower() if comment else ""
            hport_int = int(hport)
            if "gateway" in comment_lower or cport == "30080":
                ports["gateway"] = hport_int
            elif "buscacep" in comment_lower or cport == "30000":
                ports["buscacep"] = hport_int
            elif "openobserve" in comment_lower or cport == "30580":
                ports["openobserve"] = hport_int
            elif "pub/sub" in comment_lower or cport == "30085":
                ports["pubsub"] = hport_int
            elif "grafana" in comment_lower or cport == "30300":
                ports["grafana"] = hport_int
            elif "pyroscope" in comment_lower or cport == "30440":
                ports["pyroscope"] = hport_int
            elif "minio" in comment_lower or cport == "30901":
                ports["minio"] = hport_int
            elif "chaos" in comment_lower or cport == "32333":
                ports["chaos_dashboard"] = hport_int
    except Exception as err:
        print(f"⚠️ Aviso: Falha ao ler kind-config.yaml: {err}")

    return ports


def parse_local_ports_from_tfvars():
    """Lê variáveis customizadas do terraform.tfvars local se existirem."""
    ports = {}
    for path in [LOCAL_TFVARS_PATH, LOCAL_VARS_PATH]:
        if not path.exists():
            continue
        try:
            content = path.read_text(encoding="utf-8")
            var_map = {
                "gateway_port": "gateway",
                "buscacep_port": "buscacep",
                "openobserve_port": "openobserve",
                "pubsub_emulator_port": "pubsub",
                "grafana_port": "grafana",
                "pyroscope_port": "pyroscope",
                "minio_port": "minio",
                "chaos_dashboard_port": "chaos_dashboard",
            }
            for var_name, key in var_map.items():
                match = re.search(rf'{var_name}\s*=\s*(\d+)', content)
                if match and key not in ports:
                    ports[key] = int(match.group(1))
        except Exception:
            pass
    return ports


def discover_gcp_load_balancers():
    """Descobre IPs externos de LoadBalancers provisionados no GKE."""
    lb_ips = {}
    code, out = run_cmd(["kubectl", "get", "svc", "-A", "-o", "json"], timeout=15)
    if code != 0 or not out:
        print(f"ℹ️ Não foi possível consultar kubectl get svc: {out}")
        return lb_ips

    try:
        data = json.loads(out)
        for item in data.get("items", []):
            spec = item.get("spec", {})
            if spec.get("type") != "LoadBalancer":
                continue

            name = item.get("metadata", {}).get("name", "")
            ingress = item.get("status", {}).get("loadBalancer", {}).get("ingress", [])
            ip = ingress[0].get("ip") or ingress[0].get("hostname") if ingress else None

            ports = spec.get("ports", [])
            port = ports[0].get("port") if ports else 80

            if ip:
                lb_ips[name] = {"ip": ip, "port": port}
            else:
                lb_ips[name] = {"ip": "<PENDING>", "port": port}
    except Exception as err:
        print(f"⚠️ Aviso ao analisar JSON dos serviços Kubernetes: {err}")

    return lb_ips


def discover_k6_reports():
    """Descobre e cataloga relatórios HTML gerados por execuções do k6."""
    reports = []
    found_files = []

    if REPORTS_DIR.exists():
        found_files.extend(list(REPORTS_DIR.glob("*.html")))

    # Inclui o load-test/report.html legado apenas se reports/ estiver vazio
    if LEGACY_REPORT_PATH.exists() and not found_files:
        found_files.append(LEGACY_REPORT_PATH)

    # Ordena por data de modificação decrescente (mais recente primeiro)
    found_files.sort(key=lambda p: p.stat().st_mtime, reverse=True)

    for idx, path in enumerate(found_files):
        stat = path.stat()
        mtime = datetime.datetime.fromtimestamp(stat.st_mtime)
        size_kb = round(stat.st_size / 1024, 1)
        size_str = f"{size_kb} KB" if size_kb < 1024 else f"{round(size_kb / 1024, 2)} MB"

        # Caminho relativo a partir de control-panel/index.html
        rel_path = f"../load-test/reports/{path.name}" if path.parent.name == "reports" else f"../load-test/{path.name}"

        reports.append({
            "id": f"k6_report_{path.stem}",
            "filename": path.name,
            "title": f"Relatório de Carga k6 ({mtime.strftime('%d/%m/%Y %H:%M:%S')})",
            "timestamp": mtime.strftime("%d/%m/%Y %H:%M:%S"),
            "size": size_str,
            "relative_url": rel_path,
            "is_latest": (idx == 0)
        })

    return reports


def sync_panel(target_env=None, do_open=False, generate_summary=False):
    """Executa a sincronização dos dados do painel e atualiza os arquivos."""
    if not LINKS_JSON_PATH.exists():
        print(f"❌ Erro: {LINKS_JSON_PATH} não encontrado.")
        sys.exit(1)

    with open(LINKS_JSON_PATH, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    active_env = target_env if target_env in ["local", "gcp"] else detect_active_env()
    catalog["active_env"] = active_env
    catalog["last_synced_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()

    print(f"🔄 Sincronizando Painel de Controle AIOps [Ambiente: {active_env.upper()}]...")

    # 1. Sincronização Local
    local_ports = parse_local_ports_from_kind_config()
    tf_ports = parse_local_ports_from_tfvars()
    # Terraform tfvars tem precedência se definido explicitamente
    for k, v in tf_ports.items():
        local_ports[k] = v

    port_mapping = {
        "openobserve": local_ports.get("openobserve", 5080),
        "grafana": local_ports.get("grafana", 3000),
        "pyroscope": local_ports.get("pyroscope", 4040),
        "buscacep_web": local_ports.get("buscacep", 8000),
        "buscacep_docs": local_ports.get("buscacep", 8000),
        "buscacep_redoc": local_ports.get("buscacep", 8000),
        "buscacep_health": local_ports.get("buscacep", 8000),
        "gateway_docs": local_ports.get("gateway", 8080),
        "gateway": local_ports.get("gateway", 8080),
        "pubsub_emulator": local_ports.get("pubsub", 8085),
        "minio_console": local_ports.get("minio", 9001),
        "chaos_dashboard": local_ports.get("chaos_dashboard", 2333),
        "k6_dashboard": 5665,
    }

    # 2. Sincronização GCP
    gcp_lbs = {}
    if active_env == "gcp":
        gcp_lbs = discover_gcp_load_balancers()

    # Atualiza cada serviço
    for svc in catalog.get("services", []):
        svc_id = svc.get("id")

        # Atualiza porta local se aplicável
        if svc_id in port_mapping and not svc.get("is_external"):
            p = port_mapping[svc_id]
            svc["local_port"] = p
            if svc_id == "buscacep_web":
                svc["local_url"] = f"http://localhost:{p}/"
            elif svc_id == "buscacep_docs":
                svc["local_url"] = f"http://localhost:{p}/docs"
            elif svc_id == "buscacep_redoc":
                svc["local_url"] = f"http://localhost:{p}/redoc"
            elif svc_id == "buscacep_health":
                svc["local_url"] = f"http://localhost:{p}/healthz"
            elif svc_id == "gateway_docs":
                svc["local_url"] = f"http://localhost:{p}/docs"
            elif svc_id == "gateway":
                svc["local_url"] = f"http://localhost:{p}/healthz"
            else:
                svc["local_url"] = f"http://localhost:{p}"

        # Atualiza URL do GCP com IPs reais
        if active_env == "gcp" and not svc.get("is_external"):
            if svc_id in ["buscacep_web", "buscacep_docs", "buscacep_redoc", "buscacep_health"]:
                lb = gcp_lbs.get("buscacep-api")
                if lb:
                    ip = lb["ip"]
                    if svc_id == "buscacep_web":
                        suffix = "/"
                    elif svc_id == "buscacep_docs":
                        suffix = "/docs"
                    elif svc_id == "buscacep_redoc":
                        suffix = "/redoc"
                    else:
                        suffix = "/healthz"
                    svc["gcp_url"] = f"http://{ip}{suffix}" if ip != "<PENDING>" else f"http://<PENDING>{suffix}"
            elif svc_id in ["gateway", "gateway_docs"]:
                lb = gcp_lbs.get("gateway")
                if lb:
                    ip = lb["ip"]
                    port_str = f":{lb['port']}" if lb['port'] != 80 else ""
                    suffix = "/docs" if svc_id == "gateway_docs" else "/healthz"
                    svc["gcp_url"] = f"http://{ip}{port_str}{suffix}" if ip != "<PENDING>" else f"http://<PENDING>:8080{suffix}"
            elif svc_id == "openobserve":
                lb = gcp_lbs.get("openobserve")
                if lb:
                    ip = lb["ip"]
                    svc["gcp_url"] = f"http://{ip}:5080" if ip != "<PENDING>" else "http://<PENDING>:5080"
            elif svc_id == "chaos_dashboard":
                lb = gcp_lbs.get("chaos-dashboard")
                if lb:
                    ip = lb["ip"]
                    port_str = f":{lb['port']}" if lb['port'] != 80 else ""
                    svc["gcp_url"] = f"http://{ip}{port_str}" if ip != "<PENDING>" else "http://<PENDING>:2333"

    # 3. Descoberta de relatórios históricos do k6
    k6_reports = discover_k6_reports()
    catalog["k6_reports"] = k6_reports

    for svc in catalog.get("services", []):
        if svc.get("id") == "k6_dashboard":
            svc["reports_count"] = len(k6_reports)
            if k6_reports:
                svc["latest_report_url"] = k6_reports[0]["relative_url"]
            else:
                svc.pop("latest_report_url", None)

    # Escreve links.json
    with open(LINKS_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)
        f.write("\n")

    # Escreve data.js para suporte a file:// sem CORS
    with open(DATA_JS_PATH, "w", encoding="utf-8") as f:
        f.write("// Catálogo de links e recursos da Plataforma AIOps (Offline-first data store)\n")
        f.write("// Atualizado automaticamente por scripts/sync_control_panel.py\n")
        f.write("window.AIOPS_DATA = ")
        json.dump(catalog, f, indent=2, ensure_ascii=False)
        f.write(";\n")

    print(f"✅ Painel de controle atualizado com sucesso!")
    print(f"📁 Arquivo HTML: file://{CONTROL_PANEL_DIR}/index.html")

    # Gera resumo em Markdown
    summary_md = generate_markdown_summary(catalog, active_env)

    if generate_summary:
        print("\n" + summary_md)

        # Se estiver no GitHub Actions, grava no $GITHUB_STEP_SUMMARY
        step_summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if step_summary_path and Path(step_summary_path).parent.exists():
            try:
                with open(step_summary_path, "a", encoding="utf-8") as f:
                    f.write("\n" + summary_md + "\n")
                print("📄 Resumo anexado com sucesso ao GitHub Step Summary!")
            except Exception as err:
                print(f"⚠️ Aviso ao gravar GITHUB_STEP_SUMMARY: {err}")

    # Abre no navegador se solicitado
    if do_open:
        index_file = CONTROL_PANEL_DIR / "index.html"
        print(f"🌐 Abrindo painel de controle no navegador padrão...")
        if sys.platform == "darwin":
            subprocess.run(["open", str(index_file)])
        elif sys.platform.startswith("linux"):
            subprocess.run(["xdg-open", str(index_file)])


def generate_markdown_summary(catalog, active_env):
    """Gera uma tabela formatada em Markdown com os links atualizados."""
    env_name = "Local (Kind)" if active_env == "local" else "GCP Cloud (GKE)"
    synced_time = catalog.get("last_synced_at", "")

    lines = [
        f"### 🎛️ Painel de Controle AIOps — Endereços Ativos [{env_name}]",
        f"**Sincronizado em:** `{synced_time}`",
        "",
        "| Categoria | Serviço / Ferramenta | URL Ativa | Credenciais / Notas |",
        "|---|---|---|---|",
    ]

    for svc in catalog.get("services", []):
        cat = svc.get("category_name", "")
        name = svc.get("name", "")
        url = svc.get("local_url" if active_env == "local" else "gcp_url", "")
        creds = svc.get("credentials")
        if creds:
            note = f"`{creds['user']}` / `{creds['pass']}`"
        elif svc.get("is_external"):
            note = "Console Web GCP"
        elif svc.get("is_on_demand"):
            note = f"Porta `:{svc.get('local_port', 5665)}` (Sob demanda — `make k6-ui`)"
        elif active_env == "local" and svc.get("local_port"):
            note = f"Porta `:{svc['local_port']}`"
        else:
            note = "-"

        lines.append(f"| {cat} | **{name}** | [{url}]({url}) | {note} |")

    k6_reports = catalog.get("k6_reports", [])
    if k6_reports:
        lines.append("")
        lines.append(f"#### 📊 Relatórios Salvos de Teste de Carga (k6) ({len(k6_reports)} encontrados)")
        lines.append("| Relatório | Data / Hora | Tamanho |")
        lines.append("|---|---|---|")
        for rep in k6_reports[:5]:
            latest_badge = " **(Mais Recente)**" if rep.get("is_latest") else ""
            lines.append(f"| `{rep['filename']}`{latest_badge} | {rep['timestamp']} | {rep['size']} |")

    lines.append("")
    lines.append(f"💡 Para abrir o painel gráfico completo no navegador, execute: `make panel`")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Sincronizador do Painel de Controle AIOps")
    parser.add_argument(
        "--env",
        choices=["local", "gcp", "auto"],
        default="auto",
        help="Ambiente alvo (default: auto-detect)",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Abre o painel index.html no navegador padrão",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Exibe tabela resumo em Markdown e grava no $GITHUB_STEP_SUMMARY se disponível",
    )

    args = parser.parse_args()
    target_env = None if args.env == "auto" else args.env
    sync_panel(target_env=target_env, do_open=args.open, generate_summary=args.summary)


if __name__ == "__main__":
    main()
