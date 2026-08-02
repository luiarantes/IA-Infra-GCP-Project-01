# sample-app: podinfo (fase 3)

Aplicação de teste implantada no cluster via `.github/workflows/deploy-app.yml`.
Usamos [podinfo](https://github.com/stefanprodan/podinfo) — imagem pública
já pronta para demos de observabilidade (métricas Prometheus, logs
estruturados, endpoints que simulam falhas), então não precisamos escrever
uma aplicação do zero para ter algo "real" no cluster.

## Arquivos

- `deployment.yaml` — 1 réplica, com `resources.requests` explícitos
  (obrigatório no GKE Autopilot) e probes de readiness/liveness
- `service.yaml` — `ClusterIP` (não `LoadBalancer`, para não gerar custo
  de IP público desnecessário)

## Como acessar depois do deploy

```bash
gcloud container clusters get-credentials aiops-gke --region us-central1 --project ia-infra-gcp-project-01
kubectl port-forward svc/podinfo 9898:9898
```

Depois acesse `http://localhost:9898` — o podinfo tem uma UI simples e
endpoints como `/healthz`, `/readyz`, `/metrics` e `/panic` (simula um
crash, útil para testar o self-healing nas fases 5-7).
