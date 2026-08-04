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
