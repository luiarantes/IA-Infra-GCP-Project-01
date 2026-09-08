# Guia de Integração com Internal Developer Platform (IDP)

Este documento orienta como conectar este repositório a plataformas de engenharia modernas como **Spotify Backstage** (open-source) e **Port** (SaaS), aproveitando os padrões de **Service Catalog**, **Golden Paths** e **Observabilidade Unificada**.

---

## 1. Visão Geral da Arquitetura do IDP

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │                 INTERNAL DEVELOPER PORTAL (Backstage / Port)           │
  │                                                                        │
  │  [ Software Catalog ]        [ Golden Path Scaffolder ]   [ Operations ]
  │  • gateway                   • microservice-template     • OpenObserve
  │  • service-api               • Terraform modules         • AIOps Self-Healing
  │  • service-worker                                                      │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │
                                      ▼
                        [ GitHub Repo & CI/CD Pipelines ]
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            ▼                                                   ▼
   [ Local Kind (Docker) ]                             [ GCP GKE / AWS EKS ]
```

---

## 2. Padrão de Metadados: `catalog-info.yaml`

Cada microsserviço no repositório (`apps/*`) possui um arquivo `catalog-info.yaml` em conformidade com as especificações da CNCF/Backstage:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: gateway
  title: Gateway Service
  description: Ponto de entrada público e roteador de borda da malha de microsserviços.
  tags:
    - python
    - fastapi
    - opentelemetry
  annotations:
    github.com/project-slug: luiarantes/IA-Infra-GCP-Project-01
    openobserve.io/service-name: gateway
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  type: service
  lifecycle: production
  owner: platform-team
  system: aiops-platform
```

---

## 3. Como Importar no Spotify Backstage

1. No seu portal Backstage, acesse **Catalog** -> **Register Existing Component**.
2. Insira a URL do arquivo no GitHub:
   ```
   https://github.com/luiarantes/IA-Infra-GCP-Project-01/blob/main/apps/gateway/catalog-info.yaml
   ```
3. O Backstage importará automaticamente a topologia de dependências, links do repositório, documentação TechDocs e métricas.

---

## 4. Como Importar no Port (getport.io)

1. No painel do **Port**, utilize a integração nativa com o GitHub ou o **Port Ocean Exporter**.
2. Configure o importador de `catalog-info.yaml` para mapear automaticamente para o Blueprint `Service` do Port.
3. Crie **Self-Service Actions** utilizando o template em `templates/microservice-template/` disparado via GitHub Actions.

---

## 5. Links Rápidos de Telemetria no Portal

Ao acessar qualquer componente no catálogo do IDP, configure os links de atalho para a telemetria:

* **Traces & Logs Correlacionados**: `http://<OPENOBSERVE_IP>:5080/web/traces?service=<SERVICE_NAME>`
* **Métricas Prometheus**: `http://<OPENOBSERVE_IP>:5080/web/metrics`
* **Healthcheck**: `http://<SERVICE_IP>:8080/healthz`
