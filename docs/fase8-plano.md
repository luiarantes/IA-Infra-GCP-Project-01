# Fase 8: microsserviços reais, tracing distribuído e teste de carga

> Documento de planejamento para continuar em uma nova conversa. As fases
> 0 a 7 estão completas e validadas (ver `README.md` e o histórico de
> commits) — este arquivo captura o que foi decidido para a próxima fase,
> ainda não implementada.

## Objetivo

Substituir/complementar o podinfo (fases 3-7) por uma arquitetura de
microsserviços mais rica, capaz de exercitar cenários que o podinfo não
cobre: filas, comunicação entre serviços, um gateway, rastreamento
distribuído, e autoscaling sob carga real (em vez de sinais forçados
manualmente como fizemos até agora).

## Decisões já tomadas

### Arquitetura da aplicação placeholder (para testar a infra da fase 8)

- **4 serviços**: `gateway`, `service-api`, `service-worker`,
  `service-downstream`
- **Fluxo**: cliente → `gateway` → `service-api` → publica no Pub/Sub →
  `service-worker` consome → chama `service-downstream`
- **Stack**: Python + FastAPI em todos os serviços
- **Gateway**: serviço FastAPI customizado, não Envoy nem Cloud API
  Gateway — decisão para não acumular tecnologia nova demais na mesma
  fase (Envoy fica como evolução futura, é um upgrade natural depois que
  o resto estiver validado)
- **Lógica de negócio**: placeholder/fake por enquanto. O objetivo desta
  etapa é testar a infraestrutura (fila, tracing, roteamento, HPA), não
  resolver um problema real

### Aplicação real (em paralelo, repositório separado)

- Repositório **novo**, separado do `AIOPS-GCP-Project` — mesmo padrão já
  usado com o podinfo, que também é um repositório externo
  (`stefanprodan/podinfo`); este repo só teria os manifests referenciando
  as imagens publicadas, nunca o código-fonte
- Desenvolvida **100% local com Docker** (docker-compose), sem nenhuma
  dependência do GCP enquanto não estiver pronta
- Quando pronta: troca os manifests do placeholder pelos da aplicação
  real, reaproveitando toda a infraestrutura já validada (fila, tracing,
  gateway, HPA) — não precisa redescobrir nada
- **Só nesse momento** criar um binding de Workload Identity Federation
  novo e restrito só a esse repositório (least privilege: só
  `artifactregistry.writer`, não as permissões amplas do CI principal) —
  não alargar o binding do bootstrap existente para aceitar múltiplos
  repositórios, isso enfraqueceria a garantia de "só este repo específico
  pode agir como essa service account"
- Pendente: nome do repositório e se será público ou privado

### Rastreamento distribuído

- **Cloud Trace**, não Jaeger — consistente com o padrão "GCP nativo em
  vez de self-hosted" já seguido no projeto (Managed Prometheus na fase
  4, em vez de Prometheus/Grafana próprios)
- Instrumentação via SDK do **OpenTelemetry**, com exportador para Cloud
  Trace
- **Peça de IAM nova**: os *pods* (não só o CI) vão precisar de
  identidade própria no GCP — **Workload Identity do GKE** (KSA vinculado
  a uma GSA com `roles/cloudtrace.agent`). Isso é diferente do WIF do
  GitHub Actions usado até agora, que só autentica o pipeline de CI,
  nunca os workloads rodando no cluster
- Trace context entre chamadas HTTP: propagado automaticamente pelo
  OpenTelemetry
- Trace context entre mensagens do Pub/Sub: precisa ser propagado
  manualmente nos atributos da mensagem (não é automático)

### Fila

Reaproveita o Pub/Sub já configurado desde a fase 1 (`infra/modules/budget`
já tem o padrão de topic+subscription) — um tópico/subscription novo,
dedicado ao fluxo da aplicação, separado do `budget-alerts`.

### Teste de carga e autoscaling

- **Não existe "node dedicado"** no GKE Autopilot — ele não expõe node
  pools gerenciáveis manualmente, aloca recursos automaticamente por pod
- Em vez disso: um `Job` do Kubernetes rodando **k6** (ou Locust),
  disparado sob demanda (`workflow_dispatch`), não continuamente — mesma
  lógica de custo já aplicada aos agentes (fase 5)
- Para a carga realmente escalar **réplicas** (não só uso de CPU/memória
  de um pod único), é preciso configurar um
  **`HorizontalPodAutoscaler` (HPA)** nos serviços — peça de infra nova,
  não existe hoje em nenhum dos manifests

### Acesso externo

- O custo real está no **Load Balancer por hora ativo** (~$0,025/h), não
  na ferramenta de gateway em si
- Como o ambiente é destruído ao final de cada sessão de teste (hábito já
  estabelecido), esse custo é irrelevante (centavos por sessão, não um
  valor fixo mensal)
- `Service type=LoadBalancer` no `gateway`, acesso via IP direto — sem
  necessidade de domínio/DNS por enquanto. HTTPS com domínio próprio fica
  para depois, se fizer sentido (exigiria um recurso `Ingress` gerenciado
  em vez do `Service` puro, para ter certificado TLS)

### Generalizar observabilidade e agentes

- `infra/modules/observability` já aceita `app_label` como variável —
  a solução é **instanciar o módulo uma vez por app/serviço** em vez de
  generalizar tudo numa única invocação
- Os agentes (`agents/log-analyzer/TASK.md`, `agents/pr-creator/TASK.md`)
  hoje **assumem que é sempre o podinfo** (mencionam o nome, o endpoint
  `/panic`, etc.) — precisam ser reescritos para receber como contexto/
  parâmetro qual app e quais sinais investigar, em vez de texto fixo no
  prompt

## Ritmo de execução

Incremental, testado a cada sub-fase — mesmo padrão que revelou bugs reais
em cada etapa das fases 5, 6 e 7, em vez de acumular complexidade e testar
tudo de uma vez:

1. **8.1** — Os 4 serviços placeholder (skeleton funcional, lógica fake)
   + deploy no cluster
2. **8.2** — Rastreamento distribuído (Cloud Trace + Workload Identity do
   GKE)
3. **8.3** — Teste de carga (Job k6/Locust) + HPA
4. **8.4** — Generalizar observabilidade e agentes para múltiplos apps

## Próximos passos imediatos ao retomar

1. Construir o placeholder (4 serviços FastAPI) em `apps/` deste
   repositório
2. Criar o repositório novo (vazio, estrutura inicial) para a aplicação
   real — falta decidir nome e visibilidade
3. Seguir a ordem 8.1 → 8.2 → 8.3 → 8.4, testando cada uma antes de
   avançar para a próxima

## Contexto operacional para lembrar

- Projeto GCP: `ia-infra-gcp-project-01` (mesma conta/billing account das
  fases anteriores — ver `infra/bootstrap/README.md`)
- Ambiente foi **destruído** ao final da sessão das fases 0-7; o
  bootstrap (fase 0) permanece intacto, não precisa ser refeito
- Repositório é público no GitHub (`luiarantes/IA-Infra-GCP-Project-01`) —
  manter a documentação em linguagem neutra, sem referências a
  entrevista/vaga/portfólio
- Terraform e `gh` CLI já instalados e autenticados na máquina local
  usada nas sessões anteriores
