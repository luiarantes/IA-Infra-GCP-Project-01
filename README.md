# AIOps GCP Project

Plataforma efêmera de Kubernetes na Google Cloud, provisionada inteiramente
por código (Terraform) e implantada via GitHub Actions, com uma stack de
observabilidade monitorada por agentes de IA que detectam problemas,
diagnosticam a causa raiz e abrem Pull Requests de correção — sempre com
aprovação humana obrigatória antes de qualquer mudança real ser aplicada.

Projetada para rodar com um orçamento fixo: todo o ambiente é efêmero e
deve ser destruído ao final de cada sessão de teste.

## Arquitetura

```
repo/
├── infra/
│   ├── bootstrap/       # Terraform de rodada única: state bucket + Workload Identity Federation
│   ├── modules/         # network, gke, artifact-registry, budget, observability
│   └── environments/
│       └── test/        # ambiente que compõe os módulos acima
├── apps/sample-app/     # aplicação de teste implantada no cluster
├── observability/       # métricas/alertas versionados como código + manifests do Managed Prometheus
├── agents/              # agentes de IA: log-analyzer, pr-creator, verify-fix
├── docs/                # documentação de apoio
└── .github/workflows/   # CI/CD: terraform plan/apply/destroy, deploy, agentes, failsafe de custo
```

### Fluxo de self-healing

```
app gera um problema (crash, erro HTTP, latência, uso de recurso)
  → Cloud Monitoring detecta e abre um alerta
  → agente log-analyzer investiga e abre uma GitHub Issue com o diagnóstico
  → agente pr-creator avalia a issue e decide: abrir PR de correção, ou explicar por que não há nada a corrigir
  → humano revisa e aprova o merge do PR (se houver)
  → deploy automático aplica a correção
  → agente verify-fix reconsulta a métrica e confirma (ou reabre a issue) se o problema foi resolvido
```

Em paralelo, um mecanismo de failsafe monitora o gasto real na conta e
destrói o ambiente automaticamente se o orçamento configurado for
atingido, sem esperar confirmação humana.

## Pré-requisitos

### Contas

- **Google Cloud**: um projeto com billing configurado. Uma conta nova
  costuma vir com créditos gratuitos — confira o valor disponível antes
  de começar, e mantenha o hábito de destruir o ambiente ao final de cada
  sessão (passo final deste guia).
- **GitHub**: uma conta e um repositório próprio (fork deste repositório,
  ou um repositório novo com este código enviado — os dois funcionam,
  veja o passo 1).
- **Anthropic**: uma conta em [console.anthropic.com](https://console.anthropic.com)
  com créditos de API, necessária a partir da etapa dos agentes de IA.
  **Atenção**: essa conta é separada de uma eventual assinatura do
  Claude.ai (Free/Pro/Max) — billing de API e billing de assinatura de
  chat são contas diferentes, mesmo usando o mesmo login.

### Ferramentas locais

| Ferramenta | Para quê |
|---|---|
| `git` | clonar e versionar o repositório |
| `gcloud` (Google Cloud SDK) | autenticar e interagir com o GCP |
| `terraform` >= 1.5 | provisionar a infraestrutura |
| `gh` (GitHub CLI) | criar repositório, secrets, disparar workflows |
| `kubectl` | interagir com o cluster |
| `gke-gcloud-auth-plugin` | plugin obrigatório para o `kubectl` autenticar em clusters GKE (client-go >= 1.26 removeu a autenticação nativa de cada cloud provider) — instalado via `gcloud components install gke-gcloud-auth-plugin` |
| `jq` | processar JSON em alguns comandos de verificação |

Use os instaladores oficiais de cada ferramenta:
[gcloud](https://cloud.google.com/sdk/docs/install) ·
[Terraform](https://developer.hashicorp.com/terraform/install) ·
[gh](https://cli.github.com/) ·
[kubectl](https://kubernetes.io/docs/tasks/tools/) ·
[jq](https://jqlang.org/download/).

`kubectl` também pode ser instalado via `gcloud components install
kubectl`, se preferir manter tudo dentro do próprio Google Cloud SDK.

> **Nota sobre o Terraform**: desde a mudança de licença da HashiCorp
> (BUSL), o Terraform saiu dos gerenciadores de pacote genéricos em
> alguns sistemas (ex: `homebrew-core`) e precisa de um repositório
> específico da HashiCorp — veja o guia oficial de instalação acima. A
> alternativa 100% open-source é o [OpenTofu](https://opentofu.org/)
> (comando `tofu` em vez de `terraform`, sintaxe idêntica).

---

## Passo a passo completo

### 1. Obter o código

Duas opções, ambas funcionam — a única exigência é que o código esteja
num repositório GitHub que **você controla** (a automação de CI precisa
de permissão para criar secrets e disparar workflows nele):

**Opção A — fork:**
```bash
gh repo fork <URL_DESTE_REPOSITORIO> --clone
cd <NOME_DO_REPOSITORIO>
```

**Opção B — clonar e enviar para um repositório novo seu:**
```bash
git clone <URL_DESTE_REPOSITORIO>
cd <NOME_DO_REPOSITORIO>
git remote remove origin
gh repo create SEU_USUARIO/NOME_DO_REPO --private --source=. --remote=origin --push
```

### 2. Criar o projeto GCP e vincular o billing

```bash
gcloud auth login
```

```bash
gcloud projects create SEU_PROJECT_ID --name="Nome do projeto"
```

```bash
gcloud config set project SEU_PROJECT_ID
```

```bash
gcloud billing accounts list
```

```bash
gcloud billing projects link SEU_PROJECT_ID --billing-account=SEU_BILLING_ACCOUNT_ID
```

```bash
gcloud projects describe SEU_PROJECT_ID --format='value(projectNumber)'
```

Guarde o `projectNumber` retornado — vai ser usado nos secrets do GitHub
mais adiante.

### 3. Autenticar o Terraform localmente

O `gcloud auth login` do passo anterior autentica só o CLI do `gcloud`. O
provider do Terraform para GCP usa credenciais separadas:

```bash
gcloud auth application-default login
```

### 4. Rodar o bootstrap (uma única vez)

Este Terraform cria o bucket de state remoto e a autenticação via
Workload Identity Federation que o restante do pipeline vai usar — por
isso roda manualmente, uma vez, com suas próprias credenciais:

```bash
cd infra/bootstrap
```

```bash
terraform init
```

```bash
terraform apply \
  -var="project_id=SEU_PROJECT_ID" \
  -var="state_bucket_name=SEU_PROJECT_ID-tfstate" \
  -var="github_org=SEU_USUARIO_OU_ORG" \
  -var="github_repo=NOME_DO_REPO"
```

Confirme com `yes`. Ao final, guarde os três outputs — vão virar secrets
do GitHub no próximo passo. Detalhes adicionais em
[`infra/bootstrap/README.md`](infra/bootstrap/README.md).

### 5. Conceder permissão de billing (necessário para os alertas de orçamento)

A service account criada no bootstrap não recebe automaticamente
permissão sobre a billing account — é um escopo diferente do projeto, e
por segurança precisa ser concedido manualmente:

```bash
gcloud billing accounts add-iam-policy-binding SEU_BILLING_ACCOUNT_ID \
  --member="serviceAccount:$(terraform output -raw github_actions_service_account_email)" \
  --role="roles/billing.costsManager"
```

### 6. Configurar os secrets do GitHub

```bash
cd ..  # volta pra raiz do repositorio
```

Seis secrets, todos derivados de valores já coletados:

```bash
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "$(cd infra/bootstrap && terraform output -raw workload_identity_provider)"
```

```bash
gh secret set GCP_SERVICE_ACCOUNT --body "$(cd infra/bootstrap && terraform output -raw github_actions_service_account_email)"
```

```bash
gh secret set TF_STATE_BUCKET --body "$(cd infra/bootstrap && terraform output -raw state_bucket_name)"
```

```bash
gh secret set GCP_PROJECT_ID --body "SEU_PROJECT_ID"
```

```bash
gh secret set GCP_PROJECT_NUMBER --body "SEU_PROJECT_NUMBER"
```

```bash
gh secret set GCP_BILLING_ACCOUNT_ID --body "SEU_BILLING_ACCOUNT_ID"
```

Confirme que os seis foram criados:

```bash
gh secret list
```

### 7. Aplicar a infraestrutura base

```bash
gh workflow run terraform-apply.yml
```

```bash
gh run watch
```

Isso cria: VPC, cluster GKE Autopilot, Artifact Registry, orçamento com
alertas automáticos, e seis políticas de alerta no Cloud Monitoring
(restart de container, CPU alta, memória alta, erros HTTP 5xx, latência
elevada, e erros de aplicação via log). A criação do cluster leva
tipicamente 8-10 minutos.

### 8. Implantar a aplicação de teste

O mesmo push do passo 1 provavelmente já disparou o workflow de deploy
automaticamente (ele reage a qualquer mudança em `apps/**`) — mas como
isso aconteceu **antes** do cluster existir, é esperado que essa primeira
tentativa falhe. Depois que o passo 7 terminar, dispare de novo:

```bash
gh workflow run deploy-app.yml
```

```bash
gh run watch
```

### 9. Acessar a aplicação localmente

```bash
gcloud container clusters get-credentials aiops-gke --region us-central1 --project SEU_PROJECT_ID
```

```bash
kubectl get pods
```

Deve aparecer um pod `podinfo-...` com status `1/1 Running`. Como o
serviço é `ClusterIP` (sem IP público, de propósito, para não gerar
custo de Load Balancer desnecessário), o acesso é sempre via túnel:

```bash
kubectl port-forward svc/podinfo 9898:9898
```

Abra `http://localhost:9898` no navegador. `Ctrl+C` encerra o túnel.

### 10. Testar a stack de observabilidade

Com o túnel do passo anterior ativo, cada comando abaixo provoca um tipo
diferente de incidente:

```bash
# reinício de container
curl http://localhost:9898/panic
```

```bash
# erro HTTP 5xx
curl http://localhost:9898/status/500
```

```bash
# latência elevada (2 segundos de delay simulado)
curl http://localhost:9898/delay/2
```

CPU e memória altas não têm endpoint dedicado — provoque manualmente:

```bash
# CPU: queima um nucleo de dentro do container por 60s
POD=$(kubectl get pods -l app=podinfo -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -- sh -c "timeout 60 yes > /dev/null &"
```

Detalhes de cada cenário, incluindo como conferir as métricas brutas, em
[`observability/README.md`](observability/README.md).

### 11. Configurar e testar os agentes de IA

Gere uma API key em `console.anthropic.com` (Settings → API Keys) e
configure o secret:

```bash
gh secret set ANTHROPIC_API_KEY
```

(sem `--body`, o comando pede para colar o valor de forma oculta)

Provoque um incidente (passo 10) e dispare o agente de diagnóstico:

```bash
gh workflow run agent-log-analyzer.yml
```

```bash
gh run watch
```

Se o pre-check (sem custo de API) encontrar um sinal, o Claude Code
investiga e abre uma GitHub Issue com o diagnóstico, rotulada
`agent-finding`. Isso, por sua vez, dispara automaticamente o segundo
agente:

```bash
gh run list --workflow=agent-pr-creator.yml
```

Ele avalia a issue e decide: abrir um Pull Request de correção (rotulado
`agent-fix`) ou comentar explicando por que nenhuma mudança é necessária.
Detalhes de arquitetura de cada agente em
[`agents/log-analyzer/README.md`](agents/log-analyzer/README.md) e
[`agents/pr-creator/README.md`](agents/pr-creator/README.md).

Para testar o terceiro agente (verificação pós-merge), é preciso um PR
`agent-fix` de fato mergeado — se nenhum incidente real gerar um
naturalmente, dá para simular: crie uma branch `agent-fix/issue-N`
(onde `N` é o número de uma issue existente), faça uma alteração
pequena em `apps/sample-app/deployment.yaml`, abra um PR com
`gh pr create --label agent-fix` e mergeie. O merge dispara o deploy da
mudança e, alguns minutos depois, o agente `verify-fix` reconsulta a
métrica e comenta o resultado na issue original. Detalhes em
[`agents/verify-fix/README.md`](agents/verify-fix/README.md).

### 12. Testar o failsafe de custo

```bash
gh workflow run cost-failsafe.yml
```

Roda também automaticamente a cada 30 minutos. Se o gasto real atingir
100% do orçamento configurado, esse workflow dispara o `terraform-destroy`
sozinho, sem esperar aprovação humana — é o único ponto do projeto onde
isso acontece de propósito.

### 13. Destruir o ambiente

**Sempre execute isto ao terminar uma sessão de teste:**

```bash
gh workflow run terraform-destroy.yml -f confirm=destroy
```

```bash
gh run watch
```

Isso remove VPC, cluster, Artifact Registry, orçamento e todas as
políticas de alerta. O bootstrap (bucket de state e Workload Identity
Federation) permanece intacto — retomar depois é só repetir o passo 7 em
diante, sem precisar refazer o bootstrap.

### 14. Implantar os microsserviços (gateway, service-api, service-worker, service-downstream)

> Se você já tinha rodado o passo 4 (bootstrap) antes desta atualização
> do repositório, rode o mesmo comando de novo em `infra/bootstrap` —
> duas roles novas foram adicionadas à service account do CI, exigidas
> pela identidade do GKE (Workload Identity) que esses serviços usam
> para falar com o Pub/Sub.

Além do podinfo, o repositório também implanta um fluxo de
microsserviços (`cliente → gateway → service-api → Pub/Sub →
service-worker → service-downstream`), usado para exercitar fila,
tracing distribuído e autoscaling em fases futuras. O passo 7
(`terraform-apply.yml`) já criou a fila do Pub/Sub e a identidade do GKE
junto com o resto da infraestrutura — falta só implantar os serviços:

```bash
gh workflow run deploy-microservices.yml
```

```bash
gh run watch
```

### 15. Testar o fluxo de microsserviços ponta a ponta

```bash
kubectl get pods
```

Devem aparecer `gateway`, `service-api`, `service-worker` e
`service-downstream`, todos `1/1 Running` — junto com o `podinfo` do
passo 9. Diferente dos outros serviços do projeto, o `gateway` é exposto
via `LoadBalancer` (é o único ponto de entrada público desse fluxo):

```bash
kubectl get svc gateway
```

Aguarde o `EXTERNAL-IP` deixar de ser `<pending>` (leva 1-2 minutos), e
então:

```bash
curl -X POST http://EXTERNAL_IP:8080/work -H 'Content-Type: application/json' -d '{"hello":"world"}'
```

Deve retornar `{"status":"accepted","request_id":"..."}` com HTTP 202.
Confirme que a mensagem foi consumida e processada de ponta a ponta:

```bash
kubectl logs deployment/service-worker --tail=20
```

Deve aparecer o `request_id` recebido e o resultado devolvido pelo
`service-downstream`.

### 16. Destruir o ambiente da fase de microsserviços

O mesmo passo 13 (`terraform-destroy.yml`) já cobre tudo: remove também a
fila do Pub/Sub, a identidade do GKE e os 4 serviços novos, junto com o
restante da infraestrutura.

### 17. Ver o rastreamento distribuído no Cloud Trace (fase 8.2)

> Faça isso **antes** do passo 16, enquanto o ambiente ainda está no ar —
> este passo só existe pra documentar a fase 8.2, que foi implementada
> depois da 8.1 (por isso aparece no final do guia, fora de ordem).

Os 4 serviços exportam spans reais para o Cloud Trace via OpenTelemetry
(propagação automática entre chamadas HTTP; manual, via atributos da
mensagem, na travessia pelo Pub/Sub). Repita o teste do passo 15
(`POST /work` no gateway) e pegue o `trace_id` no log:

```bash
kubectl logs deployment/gateway --tail=20
```

Deve aparecer uma linha `trace_id=... request_id=...`. Abra o Trace
Explorer no Console (troque `SEU_PROJECT_ID`):

```
https://console.cloud.google.com/traces/list?project=SEU_PROJECT_ID
```

Busque pelo `trace_id` copiado. Deve aparecer um único trace atravessando
os 4 serviços (`gateway` → `service-api` → `service-worker` →
`service-downstream`), incluindo o span manual
`service-worker.process_message` — o único trecho do fluxo sem
propagação automática de HTTP, já que o Pub/Sub não carrega o trace
context sozinho.

---

## Padrões de engenharia seguidos

- **Infrastructure as Code / GitOps**: nenhuma mudança de infraestrutura
  é manual, só via Terraform versionado e aplicado por CI
- **Zero standing credentials**: autenticação do CI via Workload Identity
  Federation — nenhuma chave JSON de service account é armazenada
- **Least privilege**: cada componente (pipeline de infra, cada agente)
  tem permissões restritas ao que sua função exige, nunca acesso amplo
- **Ephemeral environments**: o ambiente inteiro é descartável por
  design, com custo proporcional ao tempo realmente ligado
- **Sinal de plataforma, não de aplicação**: os alertas usam métricas
  nativas do Kubernetes/GKE sempre que possível, em vez de depender de
  convenções de log específicas de cada aplicação
- **Human-in-the-loop**: qualquer PR de correção exige aprovação humana
  antes do merge — a única exceção deliberada é o failsafe de custo
- **Custo proporcional à necessidade real**: os agentes fazem uma
  checagem barata (sem IA) antes de acionar uma chamada de API paga, e
  etapas puramente mecânicas (como a verificação pós-merge) não usam IA
  nenhuma

## Solução de problemas comuns

**`ERROR: (gcloud.container.clusters.get-credentials) ResponseError: code=403`**
A conta ativa no `gcloud` não é a dona do projeto. Confira com
`gcloud config get-value account` e troque com
`gcloud config set account SEU_EMAIL` se necessário.

**`kubectl` trava com `dial tcp ... i/o timeout` ao acessar o cluster**
Sintoma de rede local (firewall, roteador doméstico com alguma proteção
ativa) bloqueando conexão direta ao IP do control plane — não é
relacionado à infraestrutura. Teste em outra rede (hotspot do celular)
para confirmar, ou use o Cloud Shell do Console do GCP como alternativa
temporária.

**`Error: Error creating AlertPolicy: ... Cannot find metric(s) that match type = "..."`**
Condição de corrida entre Cloud Logging e Cloud Monitoring: uma métrica
de log recém-criada pode levar alguns minutos para ficar disponível para
outras APIs consultarem. Rodar o `terraform apply` de novo depois de
alguns minutos resolve; o módulo `infra/modules/observability` já inclui
uma espera (`time_sleep`) para isso não acontecer na maioria dos casos.

**`Error: Error creating Budget: ... Request contains an invalid argument`**
A moeda especificada não bate com a moeda real da billing account.
Confira com `gcloud billing accounts describe SEU_BILLING_ACCOUNT_ID
--format='value(currencyCode)'` e ajuste a variável
`budget_currency_code` no ambiente Terraform de acordo.

**`gh` reclama de `fatal: not a git repository` num workflow**
Algum job do GitHub Actions que usa `gh` sem ter feito `actions/checkout`
antes — o `gh` normalmente descobre o repositório-alvo pelo remote do
Git local. A correção é declarar `GH_REPO: ${{ github.repository }}`
como variável de ambiente do passo.

**Um workflow com `on: issues: types: [labeled]` nunca dispara**
O GitHub só emite o evento `labeled` quando um label é adicionado a uma
issue **já existente**. Se o label já vier junto na criação da issue
(`gh issue create --label ...`), só o evento `opened` é disparado —
escute os dois tipos e verifique a lista de labels diretamente, em vez
de depender de um campo que só existe num dos dois eventos.

**Erro `Credit balance is too low` ao rodar um agente**
A conta da API da Anthropic (`console.anthropic.com`) tem billing
separado de uma eventual assinatura do Claude.ai — adicione créditos na
própria conta de API.

**GKE Autopilot ignora limites de recurso muito baixos**
O Autopilot impõe um piso mínimo de CPU/memória por container
(atualmente 50m CPU / 52Mi memória) — valores abaixo disso são ajustados
automaticamente para esse piso, com um evento de auditoria
(`autopilot.gke.io/resource-adjustment`) registrando o ajuste.
