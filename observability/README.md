# observability (fase 4)

Stack de observabilidade nativa da GCP — sem Prometheus/Loki/Grafana
self-hosted, para não gerar custo extra de compute.

## O que já existe

- **Coleta de logs**: automática. Todo cluster GKE Autopilot já envia logs
  de todos os pods para o Cloud Logging por padrão, sem configuração
  adicional.
- **Métricas de aplicação**: [Google Cloud Managed Service for
  Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus)
  (GMP), também ativo por padrão no Autopilot. O arquivo
  [`podmonitoring.yaml`](podmonitoring.yaml) diz ao GMP para fazer scrape
  do endpoint `/metrics` do podinfo — sem isso, só métricas de sistema
  (CPU/memória) seriam coletadas, não as de aplicação.
- **Métrica baseada em log + alerta**: `infra/modules/observability/`
  (Terraform) cria uma métrica que conta logs de severidade `ERROR+` do
  `sample-app` e uma política de alerta no Cloud Monitoring que dispara
  quando essa contagem passa de `error_threshold` (default: qualquer erro)
  numa janela de 5 minutos.

## Por que sem `notification_channels`

A política de alerta não está conectada a e-mail/Slack de propósito. O
objetivo aqui não é notificar uma pessoa — é o **agente de IA (fase 5)**
consultar essas políticas via API (`Cloud Monitoring API` /
`Cloud Logging API`) e decidir sozinho o que fazer. Alertas para humanos
podem ser adicionados depois, se fizer sentido.

## Como consultar manualmente

```bash
# ver os logs de erro do sample-app
gcloud logging read 'resource.type="k8s_container" resource.labels.namespace_name="default" severity>=ERROR' --limit 20

# ver as políticas de alerta configuradas
gcloud alpha monitoring policies list --format="table(displayName,enabled)"
```

Para gerar um erro de teste, o podinfo tem um endpoint que simula falha:
`kubectl port-forward svc/podinfo 9898:9898` e depois `curl -X POST http://localhost:9898/panic`.
