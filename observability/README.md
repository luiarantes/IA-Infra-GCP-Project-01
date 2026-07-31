# observability (fase 4)

Placeholder para a stack de observabilidade.

Decisão do plano: usar **Cloud Logging + Google Cloud Managed Service for
Prometheus + Cloud Monitoring** nativos no MVP, em vez de Prometheus/Loki/
Grafana self-hosted no cluster — reduz custo de compute e operação, o que
importa com um orçamento fixo de $300.

Conteúdo desta pasta na fase 4:
- Log sinks (Cloud Logging → BigQuery ou Pub/Sub, para o agente de IA consultar)
- Dashboards e alerting policies do Cloud Monitoring, versionados como código
  (ex. via `google_monitoring_alert_policy` no Terraform, ou manifests do
  Managed Prometheus)
