# AIOPS GCP Project

Plataforma efêmera em GKE, provisionada via Terraform + GitHub Actions, com
uma stack de observabilidade lida por agentes de IA (Claude) que detectam
problemas, alertam e abrem PRs de self-healing. Projetada para rodar em uma
conta GCP nova com $300 de créditos — todo ambiente é destruído ao final de
cada teste.

## Arquitetura

```
repo/
├── infra/            # Terraform: bootstrap, módulos, ambiente de teste
├── apps/sample-app/  # app de teste implantada no cluster (fase 3)
├── observability/    # coleta de logs e alertas, versionados como código (fase 4)
├── agents/           # agentes Claude: log-analyzer, triage, pr-creator (fases 5-6)
├── docs/             # runbooks e ADRs
└── .github/workflows/ # CI/CD: terraform plan/apply/destroy
```

Fluxo alvo (fases 5-7): app gera logs → coletados pelo Cloud Logging →
agente de IA analisa periodicamente → diagnostica causa raiz com Claude →
abre PR com o fix → CI valida → humano aprova → CI aplica → agente confirma
que o alerta foi resolvido.

## Status do roadmap

- [x] Fase 0 — Bootstrap (state bucket, Workload Identity Federation)
- [x] Fase 1 — Infra base (VPC, GKE Autopilot, Artifact Registry, budget alert)
- [x] Fase 2 — CI/CD do Terraform validado end-to-end
- [x] Fase 3 — Deploy do app de teste (podinfo)
- [x] Fase 4 — Stack de observabilidade (restart, CPU, memória, erros 5xx, latência — validado com incidente real multi-sinal)
- [x] Fase 5 — Agente: log-analyzer → alerta (validado com crash real, issue #2)
- [x] Fase 6 — Agente: diagnóstico → PR de fix (validado — decidiu corretamente não abrir PR, issue #3)
- [x] Fase 7 — Loop completo de self-healing + failsafe de custo (ambas as partes validadas com PR real mergeado e mensagem sintética de orçamento)
- [ ] Fase 8 — Microsserviços reais, tracing distribuído e teste de carga (planejamento em [`docs/fase8-plano.md`](docs/fase8-plano.md), ainda não implementada)

## Pré-requisitos antes de usar

**Na GCP:**
- [ ] Projeto novo com billing account vinculada aos $300 de créditos
- [ ] `gcloud auth login` local, com acesso de Owner/Editor no projeto
- [ ] Terraform >= 1.5 instalado localmente (para rodar o bootstrap uma vez)

**No GitHub:**
- [ ] Repositório criado e este código com push feito
- [ ] Secrets configurados em Settings → Secrets and variables → Actions:
  `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`, `TF_STATE_BUCKET`,
  `GCP_PROJECT_ID`, `GCP_PROJECT_NUMBER`, `GCP_BILLING_ACCOUNT_ID`
  (todos saem dos outputs do bootstrap — veja abaixo)

**Anthropic (a partir da fase 5):**
- [ ] API key da Anthropic, como secret no GitHub (`ANTHROPIC_API_KEY`)
- [ ] Node.js já vem instalado nos runners `ubuntu-latest` do GitHub Actions — necessário para o `npm install -g @anthropic-ai/claude-code`, não precisa instalar nada extra

## Como rodar o bootstrap (uma única vez)

```bash
cd infra/bootstrap
terraform init
terraform apply \
  -var="project_id=SEU_PROJECT_ID" \
  -var="state_bucket_name=SEU_PROJECT_ID-tfstate" \
  -var="github_org=SEU_USUARIO_OU_ORG" \
  -var="github_repo=NOME_DO_REPO"
```

Detalhes completos, incluindo a concessão manual de permissão de billing
para o módulo de budget, em [`infra/bootstrap/README.md`](infra/bootstrap/README.md).

## Ciclo normal de uso

1. Abrir PR alterando algo em `infra/**` → dispara `terraform-plan.yml`
2. Merge na `main` → dispara `terraform-apply.yml` (sobe o ambiente)
3. Testar o que for necessário
4. Rodar manualmente o workflow `Terraform Destroy` (Actions → workflow_dispatch,
   digitando `destroy` para confirmar) → **derruba tudo antes de sair**

Nunca deixe o cluster no ar sem necessidade — o orçamento é de $300 no total.

## Como acessar o app de teste (podinfo) depois do deploy

O deploy em si é automático (push em `apps/**` dispara o
`deploy-app.yml`), mas para você acessar o app do seu computador precisa
configurar o `kubectl` localmente. Passo a passo:

**1. Ter `gcloud` e `kubectl` instalados** ([instruções oficiais](https://cloud.google.com/sdk/docs/install))

**2. Instalar o plugin de autenticação do GKE** — é obrigatório desde que
o Kubernetes removeu a autenticação nativa de cada cloud provider do
`kubectl` (client-go >= 1.26). Sem ele, `kubectl` não consegue autenticar
em cluster nenhum do GKE, **mesmo que você já tenha o `kubectl` instalado
por outro meio** (Homebrew, apt, etc. — o plugin é uma ferramenta separada,
específica do Google, e não vem junto):

```bash
gcloud components install gke-gcloud-auth-plugin
```

**3. Buscar as credenciais do cluster** (gera uma entrada no seu
`~/.kube/config`):

```bash
gcloud container clusters get-credentials aiops-gke --region us-central1 --project SEU_PROJECT_ID
```

**4. Confirmar que o pod está rodando:**

```bash
kubectl get pods
```

Deve aparecer algo como `podinfo-xxxxxxxxxx-xxxxx   1/1   Running`.

**5. Acessar o app localmente** (o Service é `ClusterIP`, ou seja, sem IP
público de propósito — acesso é sempre via túnel):

```bash
kubectl port-forward svc/podinfo 9898:9898
```

Abra `http://localhost:9898` no navegador. `Ctrl+C` no terminal encerra o
túnel quando terminar.

## Como testar o agente log-analyzer (fase 5)

O agente roda só sob demanda (`workflow_dispatch`), sem schedule
automático, para não gerar custo recorrente de API enquanto o projeto
está em teste. O pre-check cobre 5 sinais: restart de container, CPU alta,
memória alta, erros 5xx e latência elevada — ver
[`observability/README.md`](observability/README.md#como-provocar-cada-tipo-de-incidente-para-testar-os-agentes)
para como provocar cada um. Antes de rodar, configure o secret
`ANTHROPIC_API_KEY` no GitHub. Para testar:

```bash
# 1. gera um incidente de proposito no sample-app (qualquer um dos 5 tipos)
kubectl port-forward svc/podinfo 9898:9898 &
curl http://localhost:9898/panic

# 2. dispara o agente
gh workflow run agent-log-analyzer.yml

# 3. acompanha
gh run watch
```

Se não houver restart recente, o job encerra rápido no pre-check (sem
chamar a API da Anthropic). Se encontrar algo, o Claude Code investiga e
abre uma GitHub Issue com o diagnóstico, com o label `agent-finding`.
Detalhes de arquitetura em
[`agents/log-analyzer/README.md`](agents/log-analyzer/README.md).

## Como testar o agente pr-creator (fase 6)

Diferente da fase 5, este roda **automaticamente**: assim que a issue com
o label `agent-finding` é criada, o workflow dispara sozinho — não precisa
`workflow_dispatch`. Para acompanhar:

```bash
gh run list --workflow=agent-pr-creator.yml
```

O agente lê a issue, decide se existe um fix de código razoável, e ou
abre um PR com o label `agent-fix` (`Closes #N` no corpo) ou comenta na
issue explicando por que nenhuma mudança é necessária. Ele só pode editar
arquivos em `apps/` e `observability/` — nunca aplica nada diretamente.
Detalhes de arquitetura em [`agents/pr-creator/README.md`](agents/pr-creator/README.md).

## Fase 7: fechando o loop + failsafe de custo

**Verificação pós-merge** (`agent-verify-fix.yml`): quando um PR rotulado
`agent-fix` é mergeado, o `deploy-app.yml` já existente aplica a mudança
automaticamente (nada novo aqui). Esse workflow espera alguns minutos e
reconsulta a métrica de `restart_count` — se parou de subir, comenta
confirmando na issue (que o GitHub já fechou via `Closes #N`); se
continuar, **reabre a issue** para investigação humana. Sem Claude — é
uma checagem mecânica, não um julgamento. Detalhes em
[`agents/verify-fix/README.md`](agents/verify-fix/README.md).

**Failsafe de custo** (`cost-failsafe.yml`): roda a cada 30 minutos, puxa
mensagens do tópico `budget-alerts` (Pub/Sub, via `gcloud pubsub
subscriptions pull` com a mesma identidade WIF — sem Cloud Function, sem
credencial nova) e, se o gasto atingir 100% do orçamento configurado,
**dispara o `terraform-destroy.yml` automaticamente**, sem esperar
confirmação humana — abre uma issue com o label `cost-failsafe` para
deixar registrado o que aconteceu. Para testar manualmente:

```bash
gh workflow run cost-failsafe.yml
```

## Padrões seguidos neste repositório

- **GitOps / IaC modular**: nenhuma mudança de infra é manual, só via PR + CI
- **Ephemeral environments**: o ambiente inteiro é descartável por design
- **Least privilege**: autenticação do CI via Workload Identity Federation,
  sem chaves JSON estáticas
- **Human-in-the-loop**: PRs de self-healing (fases 6-7) sempre exigem
  aprovação humana antes do merge — a única exceção deliberada é o
  failsafe de custo, que destrói automaticamente por definição (é o
  próprio propósito dele)
