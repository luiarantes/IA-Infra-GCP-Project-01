#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

INFRA_DIR = Path(__file__).resolve().parent.parent.parent
APPS_DIR = (INFRA_DIR.parent.parent / "Apps" / "IA-App-GCP-Project-01").resolve()


def apply_yaml(content: str):
    subprocess.run(["kubectl", "apply", "-f", "-"], input=content.encode("utf-8"), check=True)


def main():
    print("📄 Aplicando manifestos dos microsserviços e do BuscaCEP...")

    # ServiceAccount compartilhada
    sa_path = INFRA_DIR / "apps" / "shared" / "serviceaccount.yaml"
    with open(sa_path) as f:
        apply_yaml(f.read())

    # OpenTelemetry Collector
    otel_col_path = INFRA_DIR / "observability" / "otel-collector.yaml"
    with open(otel_col_path) as f:
        apply_yaml(f.read())

    # Gateway
    with open(INFRA_DIR / "apps" / "gateway" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "gateway:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
        content = content.replace("          env:\n", "          env:\n" + env_extra)
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "gateway" / "service.yaml") as f:
        apply_yaml(f.read())
    with open(INFRA_DIR / "apps" / "gateway" / "hpa.yaml") as f:
        apply_yaml(f.read())

    # Service-API
    with open(INFRA_DIR / "apps" / "service-api" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "service-api:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
        content = content.replace("          env:\n", "          env:\n" + env_extra)
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "service-api" / "service.yaml") as f:
        apply_yaml(f.read())
    with open(INFRA_DIR / "apps" / "service-api" / "hpa.yaml") as f:
        apply_yaml(f.read())

    # Service-Downstream
    with open(INFRA_DIR / "apps" / "service-downstream" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "service-downstream:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
        content = content.replace("          env:\n", "          env:\n" + env_extra)
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "service-downstream" / "service.yaml") as f:
        apply_yaml(f.read())
    with open(INFRA_DIR / "apps" / "service-downstream" / "hpa.yaml") as f:
        apply_yaml(f.read())

    # Service-Worker
    with open(INFRA_DIR / "apps" / "service-worker" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "service-worker:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
        content = content.replace("          env:\n", "          env:\n" + env_extra)
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "service-worker" / "service.yaml") as f:
        apply_yaml(f.read())
    with open(INFRA_DIR / "apps" / "service-worker" / "hpa.yaml") as f:
        apply_yaml(f.read())

    # BuscaCEP
    if APPS_DIR.exists() and (APPS_DIR / "k8s").exists():
        print(f"📦 Aplicando manifestos do BuscaCEP a partir de: {APPS_DIR}")
        with open(APPS_DIR / "k8s" / "serviceaccount.yaml") as f:
            apply_yaml(f.read())
        with open(APPS_DIR / "k8s" / "deployment-api.yaml") as f:
            content = f.read().replace("IMAGE_PLACEHOLDER", "buscacep:local")
            env_extra = """            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
            content = content.replace("          env:\n", "          env:\n" + env_extra)
            apply_yaml(content)
        with open(APPS_DIR / "k8s" / "deployment-worker.yaml") as f:
            content = f.read().replace("IMAGE_PLACEHOLDER", "buscacep:local")
            env_extra = """            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4318/v1/traces"
            - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
              value: "http://otel-collector:4318/v1/logs"
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope:4040"
"""
            content = content.replace("          env:\n", "          env:\n" + env_extra)
            apply_yaml(content)

        with open(APPS_DIR / "k8s" / "service.yaml") as f:
            apply_yaml(f.read())
        with open(APPS_DIR / "k8s" / "hpa.yaml") as f:
            apply_yaml(f.read())
    else:
        print(f"⚠️ Diretório do BuscaCEP não encontrado em: {APPS_DIR}")

    # NodePort services para acesso direto em localhost
    local_ingress_path = INFRA_DIR / "local" / "manifests" / "local-ingress-services.yaml"
    with open(local_ingress_path) as f:
        apply_yaml(f.read())

    print("✅ Todos os manifestos foram aplicados com sucesso!")


if __name__ == "__main__":
    main()
