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

O k6 possui suporte nativo a visualização gráfica em tempo real e relatórios interativos com persistência histórica:

### 1. Web Dashboard Interativo ao Vivo + Exportação Automática
Inicia o teste abrindo o dashboard web nativo do k6 no navegador na porta `5665`, exportando automaticamente o relatório consolidado com timestamp ao final da execução:
```bash
make k6-ui
```
*(Ou acesse manualmente em `http://localhost:5665` durante a execução).*

### 2. Exportação de Relatório Gráfico HTML
Executa o teste e gera um arquivo estático `.html` rico com gráficos de Throughput (RPS), latência ($p90$, $p95$, $p99$), VUs e taxas de erro:
```bash
make k6-report
```

### 3. Persistência e Integração com o Painel de Controle
- Todos os relatórios gerados por `make k6-ui` e `make k6-report` são salvos automaticamente com timestamp em:
  `load-test/reports/k6-report-YYYYMMDD_HHMMSS.html`
- A cópia mais recente é mantida em `load-test/report.html`.
- O histórico completo de relatórios fica catalogado diretamente no **Painel de Controle AIOps** (`make panel`), permitindo consultar execuções passadas com um clique e sem necessidade de terminal.

---

## Validação Pós-Deploy (Smoke Test E2E)

Para validar a integridade de rede, resolução de DNS e comunicação entre microsserviços imediatamente após o rollout sem o custo ou tempo de um teste de carga pesado:

- **Script**: [`smoke-test.js`](smoke-test.js) (1 VU, 5 iterações rápidas validando `GET /healthz` e `POST /work`).
- **Pipeline Automática**: Executado automaticamente no workflow `.github/workflows/deploy-microservices.yml` através do Job [`smoke-job.yaml`](smoke-job.yaml) dentro do namespace `apps`.
- **Execução Local Rápida (via Gateway na porta :8080)**:
  ```bash
  make smoke-test
  ```
- **Execução no Cluster Kind (Job Kubernetes)**:
  ```bash
  make local-smoke-test
  ```

