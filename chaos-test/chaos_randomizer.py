#!/usr/bin/env python3
# =============================================================================
# Chaos Randomizer & Ground Truth Generator
# Orquestrador de engenharia de caos imprevisível para testes de AIOps.
# Suporta sorteio aleatório de falhas e gera o gabarito (Ground Truth)
# para auditoria autônoma de diagnóstico pelo Evaluator Agent.
# =============================================================================
import os
import sys
import json
import uuid
import random
import argparse
import subprocess
from datetime import datetime, timezone

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
EXPERIMENTS_DIR = os.path.join(BASE_DIR, "experiments")
GROUND_TRUTH_DIR = os.path.join(BASE_DIR, ".ground-truth")

SCENARIOS = {
    "latency-downstream": {
        "fault_category": "latency",
        "target_component": "service-downstream",
        "manifest": "latency-downstream.yaml",
        "parameters": {"action": "delay", "latency": "3000ms", "jitter": "200ms"},
        "expected_symptoms": [
            "Aumento substancial no p95/p99 de latência das requisições",
            "Possíveis timeouts ou aumento de tempo de resposta no gateway",
            "Spans do service-downstream demorados no Tempo/OpenObserve"
        ],
        "ground_truth_rca": "Degradação de latência simulada de 3000ms no service-downstream via NetworkChaos.",
        "expected_remediation": "Ajuste de timeouts de downstream, retries com backoff ou circuit-breaker; não mascarar como erro de memória."
    },
    "cascading-5xx": {
        "fault_category": "http_5xx",
        "target_component": "service-downstream",
        "manifest": "cascading-5xx.yaml",
        "parameters": {"action": "abort", "status_code": 500, "percentage": 100},
        "expected_symptoms": [
            "Aumento na taxa de erros HTTP 5xx nos logs e métricas",
            "Exceções capturadas nos logs do service-worker / gateway",
            "Spans com flag de erro no tracing distribuído"
        ],
        "ground_truth_rca": "Injeção de respostas HTTP 500 em cascata no service-downstream via HTTPChaos.",
        "expected_remediation": "Tratamento de exceções e fallbacks defensivos para indisponibilidade de downstream."
    },
    "cpu-throttling": {
        "fault_category": "cpu",
        "target_component": "service-api",
        "manifest": "cpu-throttling.yaml",
        "parameters": {"workers": 2, "load_pct": 95},
        "expected_symptoms": [
            "Utilização de limite de CPU > 80% (cpu limit_utilization)",
            "Possível acúmulo de requisições ou CFS throttling",
            "Disparo de escala horizontal no HPA do service-api"
        ],
        "ground_truth_rca": "Estresse severo de CPU (StressChaos) consumindo capacidade de processamento do service-api.",
        "expected_remediation": "Ajuste de requests.cpu e limits.cpu no deployment.yaml do service-api."
    },
    "slow-oom": {
        "fault_category": "memory",
        "target_component": "service-api",
        "manifest": "slow-oom.yaml",
        "parameters": {"workers": 1, "size": "280Mi"},
        "expected_symptoms": [
            "Utilização de limite de memória > 80% (memory limit_utilization)",
            "Terminação pelo kernel com Exit Code 137 (OOMKilled)",
            "Aumento no restart_count do container"
        ],
        "ground_truth_rca": "Esgotamento progressivo de limite de memória (StressChaos) forçando terminação OOMKilled (Exit Code 137).",
        "expected_remediation": "Aumento dos limites de memória (requests.memory: 128Mi, limits.memory: 256Mi) no deployment.yaml."
    },
    "pod-kill": {
        "fault_category": "restart_count",
        "target_component": "gateway",
        "manifest": "pod-kill.yaml",
        "parameters": {"action": "pod-kill", "target": "gateway"},
        "expected_symptoms": [
            "Terminação imediata do pod ativo do gateway",
            "Incremento na métrica restart_count",
            "Recriação automática do pod pelo controller do Deployment"
        ],
        "ground_truth_rca": "Terminação abrupta de pod (PodChaos) avaliando autocura do Deployment no Kubernetes.",
        "expected_remediation": "Validação de réplicas mínimas, probes de inicialização e resiliência a quedas de instâncias."
    }
}


def run_cmd(cmd_list):
    res = subprocess.run(cmd_list, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def apply_scenario(scenario_name: str, duration: str = "5m"):
    if scenario_name == "random":
        chosen_key = random.choice(list(SCENARIOS.keys()))
        print(f"🎲 [Sorteio]: Cenário selecionado aleatoriamente: '{chosen_key}'")
    else:
        if scenario_name not in SCENARIOS:
            print(f"❌ Cenário '{scenario_name}' não encontrado no catálogo.")
            print(f"Cenários disponíveis: {list(SCENARIOS.keys())}")
            sys.exit(1)
        chosen_key = scenario_name

    meta = SCENARIOS[chosen_key]
    manifest_path = os.path.join(EXPERIMENTS_DIR, meta["manifest"])
    if not os.path.exists(manifest_path):
        print(f"❌ Manifesto não encontrado: {manifest_path}")
        sys.exit(1)

    exp_id = f"exp-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
    now_iso = datetime.now(timezone.utc).isoformat()

    ground_truth = {
        "experiment_id": exp_id,
        "scenario_name": chosen_key,
        "fault_category": meta["fault_category"],
        "target_component": meta["target_component"],
        "parameters": meta["parameters"],
        "duration": duration,
        "injected_at": now_iso,
        "expected_symptoms": meta["expected_symptoms"],
        "ground_truth_rca": meta["ground_truth_rca"],
        "expected_remediation": meta["expected_remediation"],
        "status": "injected"
    }

    os.makedirs(GROUND_TRUTH_DIR, exist_ok=True)
    gt_file = os.path.join(GROUND_TRUTH_DIR, "ground-truth.json")
    with open(gt_file, "w", encoding="utf-8") as f:
        json.dump(ground_truth, f, indent=2, ensure_ascii=False)

    # Aplica manifesto no cluster
    code, out, err = run_cmd(["kubectl", "apply", "-f", manifest_path])
    if code != 0:
        print(f"⚠️ Aviso ao aplicar manifesto ({meta['manifest']}): {err}")
        print("Certifique-se de que os CRDs do Chaos Mesh estão instalados no cluster.")
    else:
        print(f"🌪️ [Chaos Mesh]: Experimento '{chosen_key}' aplicado com sucesso no cluster!")

    print(f"📁 Gabarito (Ground Truth) registrado com segurança em: {gt_file}")
    print(f"   - ID: {exp_id}")
    print(f"   - Categoria do Sinal: {meta['fault_category']}")
    print(f"   - Componente Afetado: {meta['target_component']}")
    print(f"   - Timestamp: {now_iso}")
    return ground_truth


def delete_all():
    print("🧹 Removendo todos os experimentos de caos do cluster...")
    for key, meta in SCENARIOS.items():
        manifest_path = os.path.join(EXPERIMENTS_DIR, meta["manifest"])
        if os.path.exists(manifest_path):
            run_cmd(["kubectl", "delete", "-f", manifest_path, "--ignore-not-found"])
    gt_file = os.path.join(GROUND_TRUTH_DIR, "ground-truth.json")
    if os.path.exists(gt_file):
        os.remove(gt_file)
    print("✅ Todos os experimentos foram removidos e o gabarito foi limpo.")


def show_status():
    gt_file = os.path.join(GROUND_TRUTH_DIR, "ground-truth.json")
    if os.path.exists(gt_file):
        with open(gt_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        print("📄 Experimento Ativo no Gabarito (Ground Truth):")
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("ℹ️ Nenhum experimento ativo no momento.")

    code, out, _ = run_cmd(["kubectl", "get", "networkchaos,httpchaos,stresschaos,podchaos", "-n", "default"])
    if code == 0 and out.strip():
        print("\nRecursos Chaos Mesh no namespace default:")
        print(out)


def main():
    parser = argparse.ArgumentParser(description="AIOps Chaos Randomizer & Ground Truth Generator")
    parser.add_argument("--scenario", default="random", help="Nome do cenário ou 'random' (padrão)")
    parser.add_argument("--action", choices=["apply", "delete", "status", "clean"], default="apply")
    parser.add_argument("--duration", default="5m", help="Duração do experimento no K8s")
    args = parser.parse_args()

    if args.action == "apply":
        apply_scenario(args.scenario, args.duration)
    elif args.action in ["delete", "clean"]:
        delete_all()
    elif args.action == "status":
        show_status()


if __name__ == "__main__":
    main()
