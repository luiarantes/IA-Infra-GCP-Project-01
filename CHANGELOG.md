# Changelog

Todas as alterações notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- **control-panel**: Execução automática do teste de conectividade (health checks) no carregamento inicial da página e em eventos de atualização (F5 / Cmd+R), validando e atualizando o status dos serviços em tempo real sem exigir acionamento manual.
- **control-panel**: Navegação por abas de plataforma no topo com filtragem contextual reativa (Todas as Plataformas, Ambiente Local Kind, Google Cloud GCP e CI/CD Automação), badges dinâmicos de contagem de recursos, persistência em localStorage e comandos de terminal dedicados por ambiente.
- **ci/cd**: Validação pós-deploy automatizada (Smoke Test E2E com k6) no workflow `deploy-microservices.yml` via Job Kubernetes efêmero no namespace `apps`, validando conectividade de rede, DNS e status HTTP 200/202 na cadeia completa de microsserviços.
- **k6**: Implementação de script dedicado de smoke test (`load-test/smoke-test.js`) e manifest de Job (`load-test/smoke-job.yaml`), com targets `make smoke-test` e `make local-smoke-test`.
- **control-panel**: Persistência histórica de relatórios gráficos HTML do k6 em `load-test/reports/` com timestamp, cópia canônica `load-test/report.html`, e nova seção no Painel de Controle com catálogo dinâmico de relatórios passados e links de acesso direto em um clique.
- **control-panel**: Adição de favicon SVG vetorial e unificação do logotipo do cabeçalho com identidade visual de radar e telemetria AIOps, garantindo renderização nítida sem dependências externas.
- **k8s**: Declaração explícita e isolamento de namespaces dedicados (`apps`, `observability` e `infra`) em `local/manifests/namespaces.yaml`, eliminando o uso do namespace `default`.
- **control-panel**: Expansão do catálogo de ferramentas com novos cards para BuscaCEP Frontend Web, Gateway Swagger OpenAPI, ReDoc, Central de Alertas e Incidentes GCP, Google Cloud Trace, Cloud Storage Terraform State e IAM Workload Identity Federation.
- **k6**: Integração nativa do k6 Web Dashboard (porta 5665) ao Painel de Controle AIOps, com status sob demanda e targets `make k6-ui` (dashboard interativo ao vivo no navegador) e `make k6-report` (exportação de relatório gráfico HTML).
- **control-panel**: Painel de Controle e Hub de Observabilidade dinâmico e 100% autocontido (offline-first), com interface visual Dark Mode, catálogo de ferramentas, métricas, atalhos de console e monitoramento de conectividade sem dependência de CDNs externas.
- **chaos-test**: Exposição nativa do Chaos Mesh Dashboard (porta 2333) sem necessidade de port-forward, configurado como `NodePort` no cluster local Kind e `LoadBalancer` (IP público) no GKE, com target `make chaos-ui` e integração direta no Painel de Controle.
- **scripts**: Atualização do `sync_control_panel.py` e catálogo do Painel de Controle (`links.json` e `data.js`) com suporte à descoberta e mapeamento dinâmico dos LoadBalancers do Grafana OSS e Pyroscope no GCP GKE.
- **scripts**: Script automatizado `sync_control_panel.py` para descoberta dinâmica de portas locais (Kind) e IPs externos de Load Balancers (GKE), com suporte a resumo em Markdown e integração com `make panel`, `make panel-sync` e GitHub Actions ($GITHUB_STEP_SUMMARY).
- **ci/cd**: Adição da ação `deploy_gpu_ollama` no workflow `diagnostics.yml` e aprimoramento em `deploy-observability.yml` para detecção dinâmica de pools de GPU (`gpu-spot-pool`), provisionando o Pod Ollama com tolerations e requests de GPU NVIDIA Spot e pré-aquecimento do modelo `qwen2.5-coder:7b`.
- **agents**: Elevação do timeout padrão do Ollama (`AIOPS_OLLAMA_TIMEOUT`) para 600s nos workflows `agent-log-analyzer.yml` e `agent-pr-creator.yml` para comportar inferências de modelos locais em janelas amplas de telemetria.
- **ci/cd**: Adição da ação `fix_iam_access` no workflow `diagnostics.yml` para restauração automatizada de permissões IAM (Owner e Container Admin) para a conta do projeto no GCP.

### Fixed
- **agents**: Aprimoramento da resiliência e prevenção de repetição de chamadas de ferramentas no motor agnóstico `agent_runner.py` e alinhamento das instruções em `agents/log-analyzer/TASK.md` com a ferramenta `create_issue`, garantindo a abertura autônoma de incidentes sem repetições cíclicas de comandos de inspeção.
- **ci/cd**: Validação e verificação robusta de conexão HTTP com o endpoint do Ollama nos workflows `agent-log-analyzer.yml` e `agent-pr-creator.yml`, capturando logs de port-forward e prevenindo falhas silenciosas de timeout.
- **ci/cd**: Extensão do timeout de conclusão do Job de Smoke Test com k6 (`k6-smoke-test`) de 60s para 180s em `deploy-microservices.yml` e adição de telemetria detalhada de status do Pod e eventos em caso de falha, prevenindo falsos positivos decorrentes do pull inicial da imagem em nós Spot do GKE.
- **ci/cd**: Atualização do workflow `diagnostics.yml` com escopo estrito para o namespace `apps` nas ações de injeção de caos e recuperação de microsserviços (`service-api`), e ampliação da inspeção para todos os namespaces do cluster (`-A`).
- **observability**: Correção de falsos positivos nos painéis de erro do Grafana (Loki), restringindo a regex de códigos 5xx e palavras-chave de erro com delimitação de palavras (`\b`) e contexto HTTP para evitar casamento indevido com portas TCP efêmeras de clientes e UUIDs de mensagens.
- **security**: Remoção de segredos estáticos codificados em Base64 nos manifestos Kubernetes do OpenObserve (`local/manifests/openobserve.yaml` e `observability/openobserve.yaml`), passando a gerar o Secret `openobserve-credentials` dinamicamente em tempo de execução via scripts e esteiras de CI/CD, eliminando alertas de secret scanners (GitGuardian).
- **observability**: Otimização do Grafana Beyla com exclusão de rotas de probes internas (`/healthz`, `/readyz`, `/metrics`, pushes de profiling) e desativação de `trace_printer` em stdout, eliminando sobrecarga e contenção de CPU na VM do Docker.
- **local**: Prevenção de colisão de portas dinâmicas no Kind através da reserva estática antecipada de `local-ingress-services.yaml` no `apply_local_manifests.py`.
- **local**: Ajuste de serviços `LoadBalancer` para `ClusterIP` em tempo de execução local, eliminando status `<pending>` e conflito com a porta `30901` do MinIO.

### Changed
- **observability**: Exposição dos serviços de interface web Grafana OSS (porta 3000) e Pyroscope (porta 4040) como `LoadBalancer` em manifests de nuvem (`observability/grafana.yaml` e `observability/pyroscope.yaml`), com conversão automática para `ClusterIP` no script de bootstrap local (`local-env.sh`), permitindo acesso direto via IP público externo no GCP sem necessidade de port-forwarding.
- **terraform**: Elevação de `max_node_count` de 2 para 4 no node pool Spot (`spot-node-pool`) no modo padrão (`simple`) e de 4 para 6 no modo distribuído, permitindo que o GKE Cluster Autoscaler acomode réplicas de surto em rolling updates, Jobs efêmeros de teste (k6) e auto-scaling horizontal dos microsserviços sem estagnação em status `Pending`.
- **ci/cd**: Adição da ação `expand_nodes` no workflow `diagnostics.yml` para ajuste dinâmico de limites do autoscaler de nós diretamente no GKE sob demanda.
- **ci/cd**: Desacoplamento do workflow de deploy em nuvem do Sample App (`.github/workflows/deploy-app.yml`), que passa a operar exclusivamente via `workflow_dispatch`, prevenindo tentativas de deploy automático contra clusters efêmeros inativos no GCP durante pushes na branch principal.
- **hpa**: Implementação de políticas de amortecimento (`behavior`) nos Horizontal Pod Autoscalers dos microsserviços (`gateway`, `service-api`, `service-worker`, `service-downstream` e template padrão) com `stabilizationWindowSeconds: 60` no scale-up e `300s` no scale-down, e elevação do target de utilização média para 80%, eliminando flapping e contenção de CPU por cold start concorrente de pods.
- **k8s**: Migração completa dos workloads de aplicação (`gateway`, `service-api`, `service-worker`, `service-downstream`, `podinfo`, `buscacep`) para o namespace `apps`.
- **observability**: Migração da stack LGTM, OpenObserve, OTel Collector, Beyla e Ollama para o namespace `observability`, com reconfiguração de endpoints e exporters via FQDN entre namespaces (`minio.infra:9000`, `otel-collector.observability:4318`, `loki.observability:3100`, `tempo.observability:3200`, `pyroscope.observability:4040`).
- **infra**: Migração dos serviços de suporte (`pubsub-emulator` e `minio`) para o namespace `infra`.
- **terraform**: Atualização dos bindings de Workload Identity Federation (WIF) para `apps/microservices-ksa`, `apps/microservices-trace-ksa`, `apps/buscacep-ksa`, `observability/loki` e `observability/tempo`, e ajuste de filtros das alert policies para `resource.labels.namespace_name="apps"`.
- **chaos-test**: Atualização dos experimentos Chaos Mesh (`PodChaos`, `StressChaos`, `NetworkChaos`, `HTTPChaos`) e Chaos Toolkit para atuarem estritamente sobre o namespace `apps`, incluindo RBAC e ConfigMaps no escopo correto.
- **agents**: Ajuste dos agentes autônomos (`log-analyzer`, `pr-creator`, `verify-fix`, `evaluator`) para leitura determinística de métricas e pods no namespace `apps`, e port-forwards da telemetria no namespace `observability`.
- **ci/cd**: Atualização dos workflows de deploy, carga e validação no GitHub Actions com criação idempotente e rollouts direcionados aos namespaces `apps` e `observability`.
- **local**: Otimização do bootstrap do cluster local com carregamento em lote de imagens Docker (`kind load docker-image`) e compilação do `agent-runner` sob demanda, reduzindo o tempo de subida para ~1m 05s.

## [0.5.0] - 2026-09-17

### Added
- Integração do **Chaos Mesh** (CNCF) no Kind e GKE Standard com catálogo de 5 cenários declarativos em CRDs (`NetworkChaos`, `HTTPChaos`, `StressChaos`, `PodChaos`).
- Injetor randômico de anomalias com geração de gabarito seguro (`chaos_randomizer.py` e `ground-truth.json`).
- Agente Avaliador autônomo (**Evaluator Agent**) com emissão automática de **Chaos Scorecard** e cálculo de acurácia de causa-raiz (RCA).
- Score Determinístico de Risco de Pull Request no `agent_runner.py` com atribuição de labels (`risk:low`, `risk:medium`, `risk:high`).
- Modo laboratório nos workflows de análise e correção do GitHub Actions (`force_run`, `target_app`, `context_hint`).
- CLI unificado de troubleshooting e engenharia de caos (`scripts/tshoot.sh` e target `make tshoot`).

### Changed
- Reforço da governança de Pull Requests para **100% de revisão humana (Human-in-the-Loop)** antes de qualquer merge ou aplicação de correções.

## [0.4.0] - 2026-09-14

### Added
- Pool de nós Spot dedicado para aceleradores GPU (`gke-spot-gpu`) no GKE Standard com suporte a NVIDIA L4.
- Toggle dual-engine para execução de modelos de IA (Metal GPU localmente via Ollama e NVIDIA L4 no GCP).
- Automação de ciclo fechado (*closed-loop self-healing*) com verificação local e diagnóstico adaptativo.
- Actions de diagnóstico e verificação de cotas globais de GPU (`GPUS_ALL_REGIONS`) no GitHub Actions.

### Fixed
- Lógica resiliente de sincronização de branches no `agent_runner.py` e ajuste de dimensionamento de memória para modelos locais.
- Aumento do timeout de criação do cluster GKE para 60 minutos tolerando filas de provisionamento do GCP.

## [0.3.0] - 2026-09-11

### Added
- Suíte completa de observabilidade Grafana Labs (Grafana, Loki, Tempo, Pyroscope e Prometheus).
- Painéis de monitoramento como código (*Dashboards as Code*) para métricas RED, consultas LogQL e traces distribuídos.
- Suporte a profiling contínuo em todos os microsserviços via Grafana Pyroscope.
- Toggle entre armazenamento em memória (simples) e armazenamento distribuído (MinIO local / Cloud Storage no GCP).

### Fixed
- Configuração do anel de compactadores em memória e readiness probe no `tempo-distributed`.
- Permissões da GSA para administração de buckets de traces e logs (`roles/storage.admin`).

## [0.2.0] - 2026-09-04

### Added
- Ambiente de desenvolvimento local com paridade funcional via Kind, OpenTelemetry Collector e OpenObserve.
- Migração de infraestrutura de GKE Autopilot para **GKE Standard Zonal** com Node Pool Spot (`e2-standard-2`/`e2-standard-4`).
- Módulos Terraform para provisionamento do app BuscaCEP (GSA, tópicos e subscriptions do Cloud Pub/Sub e políticas de alerta).
- Módulo de exportação de faturamento para dataset BigQuery (FinOps).

### Changed
- Relaxamento de `attribute_condition` do Workload Identity Federation para nível de organização, suportando múltiplos repositórios de microsserviços.

## [0.1.0] - 2026-08-10

### Added
- Scaffold inicial do Terraform: bootstrap de state bucket, VPC, Subnets, Cloud NAT e regras de firewall.
- Cluster GKE com autenticação sem chaves via Workload Identity Federation para GitHub Actions.
- Monitoramento de Golden Signals com Google Managed Prometheus (taxa de requisições, latência, erros 5xx, reinicializações e saturação de recursos).
- Esteira inicial de agentes de auto-remediação orientados a eventos (`log-analyzer`, `pr-creator`, `verify-fix`).
- Workflow de salvaguarda de custos (*cost-failsafe*) para prevenção de recursos ociosos.
- Rastreamento distribuído via Cloud Trace e testes de carga com k6 e Horizontal Pod Autoscaler (HPA).
