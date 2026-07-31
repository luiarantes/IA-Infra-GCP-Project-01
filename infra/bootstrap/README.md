# Bootstrap (fase 0)

Este Terraform cria os recursos que o pipeline do GitHub Actions precisa
existir **antes** de rodar qualquer coisa via CI: o bucket de state remoto
e a autenticação via Workload Identity Federation (sem chave JSON estática).

Roda **uma única vez, manualmente, com sua própria conta gcloud** — depois
disso o ciclo normal (plan/apply/destroy) é 100% via GitHub Actions.

## Pré-requisitos

- `gcloud auth login` já feito e `gcloud config set project <PROJECT_ID>` apontando
  para o projeto GCP novo (o mesmo que vai receber os $300 de créditos)
- Terraform >= 1.5 instalado localmente
- Você (ou a conta usada no `gcloud auth login`) precisa ter papel de
  Owner/Editor no projeto para criar IAM, service accounts e o WIF pool

## Passo a passo

```bash
cd infra/bootstrap

# nomes de bucket GCS são globais — inclua algo único, ex. seu project id
terraform init

terraform apply \
  -var="project_id=SEU_PROJECT_ID" \
  -var="state_bucket_name=SEU_PROJECT_ID-tfstate" \
  -var="github_org=SEU_USUARIO_OU_ORG" \
  -var="github_repo=NOME_DO_REPO"
```

Ao final, copie os outputs para os **Secrets** do repositório no GitHub
(Settings → Secrets and variables → Actions):

| Secret no GitHub | Output do Terraform |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT` | `github_actions_service_account_email` |
| `TF_STATE_BUCKET` | `state_bucket_name` |
| `GCP_PROJECT_ID` | o `project_id` que você passou acima |
| `GCP_PROJECT_NUMBER` | `gcloud projects describe SEU_PROJECT_ID --format='value(projectNumber)'` |
| `GCP_BILLING_ACCOUNT_ID` | `gcloud billing accounts list` |

## Sobre o módulo de budget (alertas de custo)

A service account criada aqui **não** recebe permissão automática sobre a
billing account (isso é escopo de conta de billing, não de projeto, e exige
concessão manual por segurança). Para o `infra/modules/budget` funcionar via
CI, conceda manualmente, uma vez:

```bash
gcloud billing accounts add-iam-policy-binding SEU_BILLING_ACCOUNT_ID \
  --member="serviceAccount:$(terraform output -raw github_actions_service_account_email)" \
  --role="roles/billing.costsManager"
```

Se preferir não conceder esse acesso, defina `enable_budget_alert = false`
no ambiente de teste e configure o orçamento manualmente no Console.

## State deste bootstrap

Este diretório usa **state local** de propósito (arquivo `terraform.tfstate`
aqui mesmo, já coberto pelo `.gitignore`) — é o único Terraform do projeto
que não usa o backend remoto, porque ele é quem cria esse backend. Guarde
esse arquivo com cuidado (ou rode o bootstrap de novo se precisar recriar).
