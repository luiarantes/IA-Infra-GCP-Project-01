# Testes de resiliência / chaos engineering (pós fase 8.4)

Usa o [Chaos Toolkit](https://chaostoolkit.org/) — CLI Python que fala
com a API do Kubernetes usando as credenciais normais do pod
(`ServiceAccount` do cluster, sem GCP IAM/Workload Identity nenhum).
Escolhido em vez do Chaos Mesh: testamos o Chaos Mesh de verdade nesta
sessão e confirmamos que o GKE Autopilot bloqueia o `chaos-daemon`
(rejeitado pelo GKE Warden — `hostPID`, container privilegiado e
`hostPath` em modo escrita não são permitidos em workloads que não são
do próprio sistema GKE). O Chaos Toolkit evita esse problema desde o
início: só usa a API padrão do Kubernetes (matar pod, consultar
estado), sem nenhum componente privilegiado.

Disparo sob demanda, via `.github/workflows/chaos-test.yml`
(`workflow_dispatch`) — mesma lógica de custo já usada nos agentes de
IA e no `load-test.yml`.

## Experimentos disponíveis

- **`experiment-kill-gateway.json`**: mata um pod do `gateway` e
  confirma que o Deployment se recupera sozinho. Cenário mais simples,
  sem estado em trânsito.
- **`experiment-kill-worker-mid-message.json`**: publica uma mensagem
  via `POST /work` no gateway e mata o pod do `service-worker` logo em
  seguida. O `service-worker` só dá `ack()` na mensagem depois de
  processar com sucesso — se ele morrer antes disso, o Pub/Sub deve
  reentregar a mensagem para o pod novo depois que o Deployment se
  recupera.

## Rodar localmente (sem CI)

Com `kubectl` já autenticado no cluster:

```bash
kubectl apply -f chaos-test/rbac.yaml
```

```bash
kubectl delete job chaos-test --ignore-not-found
```

```bash
kubectl create configmap chaos-experiment --from-file=experiment.json=chaos-test/experiment-kill-gateway.json --dry-run=client -o yaml | kubectl apply -f -
```

```bash
kubectl apply -f chaos-test/job.yaml
```

```bash
kubectl logs -f job/chaos-test
```

Troque o `--from-file` pelo outro experimento pra rodar o outro
cenário.
