# Teste de carga (fase 8.3)

Gera carga real contra o `gateway` (fluxo completo: gateway →
service-api → Pub/Sub → service-worker → service-downstream) pra
observar os `HorizontalPodAutoscaler` (`apps/*/hpa.yaml`) escalando
réplicas de verdade, em vez de sinais forçados manualmente.

Disparo sob demanda, via `.github/workflows/load-test.yml`
(`workflow_dispatch`) — não roda em background contínuo, mesma lógica
de custo já usada nos agentes de IA e no Job de failsafe.

## Ajustar a carga

Edite os `stages` em [`script.js`](script.js) (VUs simultâneos e
duração de cada etapa). O `job.yaml` não precisa mudar — o workflow
sempre recria o `ConfigMap` a partir do `.js` atual antes de rodar o
`Job`.

## Rodar localmente (sem CI)

Com `kubectl` já autenticado no cluster:

```bash
kubectl delete job k6-load-test --ignore-not-found
```

```bash
kubectl create configmap k6-script --from-file=script.js=load-test/script.js --dry-run=client -o yaml | kubectl apply -f -
```

```bash
kubectl apply -f load-test/job.yaml
```

```bash
kubectl logs -f job/k6-load-test
```

## Modo Gráfico e Dashboards (k6 Web UI)

O k6 possui suporte nativo a visualização gráfica em tempo real e relatórios interativos:

### 1. Web Dashboard Interativo ao Vivo
Inicia o teste abrindo o dashboard web nativo do k6 no navegador na porta `5665`:
```bash
make k6-ui
```
*(Ou acesse manualmente em `http://localhost:5665` durante a execução).*

### 2. Exportação de Relatório Gráfico HTML
Executa o teste e gera um arquivo estático `.html` rico com gráficos de Throughput (RPS), latência ($p90$, $p95$, $p99$), VUs e taxas de erro:
```bash
make k6-report
```
O relatório é gerado em `load-test/report.html` e aberto automaticamente no navegador padrão.

