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
- **Alerta de restart de container**: uma segunda política, baseada na
  métrica nativa do GKE `kubernetes.io/container/restart_count`, dispara
  sempre que um container reinicia. Ver "Limitação real encontrada" abaixo
  — este é o alerta que de fato funciona com o podinfo.

## Limitação real encontrada (testada em 2026-08-01)

Provocamos um crash de propósito (`curl -X POST /panic` no podinfo) e
descobrimos que **o alerta baseado em log (`severity>=ERROR`) nunca
dispara para essa aplicação**: o podinfo usa a biblioteca Zap, que escreve
o campo `"level"` no JSON de log, não `"severity"` (o nome que o Cloud
Logging reconhece para promover automaticamente a severidade do
`LogEntry`). Resultado: todo log do podinfo chega como `severity: INFO`,
mesmo o da própria mensagem de pânico.

Isso é uma limitação real de depender de log de aplicação como sinal de
problema: cada app loga do seu jeito, então não é um sinal genérico o
suficiente para uma plataforma de self-healing que precisa reagir a
qualquer app. Por isso existe o alerta de `restart_count` — é um sinal do
**Kubernetes**, não da aplicação, então funciona independente de como cada
app loga.

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
