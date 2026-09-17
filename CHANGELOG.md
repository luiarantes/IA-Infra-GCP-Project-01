# Changelog

Todas as alterações notáveis deste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/)
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Fixed
- **local**: Prevenção de colisão de portas dinâmicas no Kind através da reserva estática antecipada de `local-ingress-services.yaml` no `apply_local_manifests.py`.
- **local**: Ajuste de serviços `LoadBalancer` para `ClusterIP` em tempo de execução local, eliminando status `<pending>` e conflito com a porta `30901` do MinIO.

### Changed
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
