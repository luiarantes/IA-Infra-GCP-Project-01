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
- [ ] Fase 4 — Stack de observabilidade (código pronto, falta aplicar)
- [ ] Fase 5 — Agente: log-analyzer → alerta
- [ ] Fase 6 — Agente: diagnóstico → PR de fix
- [ ] Fase 7 — Loop de self-healing com aprovação humana + failsafe de custo

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

## Padrões seguidos neste repositório

- **GitOps / IaC modular**: nenhuma mudança de infra é manual, só via PR + CI
- **Ephemeral environments**: o ambiente inteiro é descartável por design
- **Least privilege**: autenticação do CI via Workload Identity Federation,
  sem chaves JSON estáticas
- **Human-in-the-loop**: PRs de self-healing (fases 6-7) sempre exigem
  aprovação humana antes do merge
