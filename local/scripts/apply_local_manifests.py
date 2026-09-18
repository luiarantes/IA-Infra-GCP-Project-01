#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

INFRA_DIR = Path(__file__).resolve().parent.parent.parent
APPS_DIR = (INFRA_DIR.parent.parent / "Apps" / "IA-App-GCP-Project-01").resolve()


def apply_yaml(content: str):
    subprocess.run(["kubectl", "apply", "--server-side", "--force-conflicts", "-f", "-"], input=content.encode("utf-8"), check=True)


def main():
    print("📄 Aplicando manifestos dos microsserviços e do BuscaCEP...")

    # 0. Criar namespaces dedicados
    namespaces_path = INFRA_DIR / "local" / "manifests" / "namespaces.yaml"
    if namespaces_path.exists():
        with open(namespaces_path) as f:
            apply_yaml(f.read())

    # 1. Aplicar NodePort services para acesso direto em localhost primeiro
    # Isso reserva as portas 30000, 30080, 30300, 30440, 30901 no Kind e evita colisões.
    local_ingress_path = INFRA_DIR / "local" / "manifests" / "local-ingress-services.yaml"
    with open(local_ingress_path) as f:
        apply_yaml(f.read())

    # ServiceAccount compartilhada
    sa_path = INFRA_DIR / "apps" / "shared" / "serviceaccount.yaml"
    with open(sa_path) as f:
        apply_yaml(f.read())

    # OpenObserve credentials secret (gerado dinamicamente em runtime para evitar credenciais estáticas no repositório)
    import base64
    oo_email = "admin@example.com"
    oo_pass = os.getenv("OPENOBSERVE_ROOT_PASSWORD", "ComplexPassword123#")
    oo_auth = "Basic " + base64.b64encode(f"{oo_email}:{oo_pass}".encode("utf-8")).decode("utf-8")
    oo_secret_yaml = f"""apiVersion: v1
kind: Secret
metadata:
  name: openobserve-credentials
  namespace: observability
type: Opaque
stringData:
  auth_header: "{oo_auth}"
  root_user_email: "{oo_email}"
  root_user_password: "{oo_pass}"
"""
    apply_yaml(oo_secret_yaml)

    # OpenTelemetry Collector
    otel_col_path = INFRA_DIR / "observability" / "otel-collector.yaml"
    with open(otel_col_path) as f:
        apply_yaml(f.read())

    # Gateway (ajustado para ClusterIP no Kind local, pois o gateway-local NodePort 30080 cuida do hostPort 8080)
    with open(INFRA_DIR / "apps" / "gateway" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "gateway:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.observability:4318/v1/traces"
"""
        content = content.replace("          env:\n", "          env:\n" + env_extra)
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "gateway" / "service.yaml") as f:
        content = f.read().replace("type: LoadBalancer", "type: ClusterIP")
        apply_yaml(content)
    with open(INFRA_DIR / "apps" / "gateway" / "hpa.yaml") as f:
        apply_yaml(f.read())

    # Service-API
    with open(INFRA_DIR / "apps" / "service-api" / "deployment.yaml") as f:
        content = f.read().replace("${IMAGE}", "service-api:local").replace("${PROJECT_ID}", "aiops-local")
        env_extra = f"""            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator.infra:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.observability:4318/v1/traces"
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
              value: "http://otel-collector.observability:4318/v1/traces"
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
              value: "pubsub-emulator.infra:8085"
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.observability:4318/v1/traces"
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
              value: "pubsub-emulator.infra:8085"
"""
            content = content.replace("          env:\n", "          env:\n" + env_extra)
            apply_yaml(content)
        with open(APPS_DIR / "k8s" / "deployment-worker.yaml") as f:
            content = f.read().replace("IMAGE_PLACEHOLDER", "buscacep:local")
            env_extra = """            - name: PUBSUB_EMULATOR_HOST
              value: "pubsub-emulator.infra:8085"
"""
            content = content.replace("          env:\n", "          env:\n" + env_extra)
            apply_yaml(content)

        # BuscaCEP API Service (ClusterIP no Kind; buscacep-api-local cuida do NodePort 30000 -> 8000)
        with open(APPS_DIR / "k8s" / "service.yaml") as f:
            content = f.read().replace("type: LoadBalancer", "type: ClusterIP")
            apply_yaml(content)
        with open(APPS_DIR / "k8s" / "hpa.yaml") as f:
            apply_yaml(f.read())
    else:
        print(f"⚠️ Diretório do BuscaCEP não encontrado em: {APPS_DIR}")

    print("✅ Todos os manifestos foram aplicados com sucesso!")


if __name__ == "__main__":
    main()
