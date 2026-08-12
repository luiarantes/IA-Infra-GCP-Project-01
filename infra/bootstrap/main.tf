# APIs necessarias apenas para o bootstrap em si
resource "google_project_service" "bootstrap_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Dataset do BigQuery Billing Export (FinOps) - fica no bootstrap, nao no
# ambiente efemero (infra/environments/test), de proposito: o objetivo e
# manter historico de custo atraves dos ciclos de destroy/apply do
# ambiente de teste. Se estivesse em environments/test, o historico seria
# apagado junto com o resto a cada terraform-destroy.
#
# O Terraform so cria o dataset - o link real "exportar billing pra este
# dataset" e configuracao da billing account, so disponivel no Console
# (nao existe comando gcloud/API publica pra isso). Depois do apply:
# Console -> Billing -> Faturamento e custos -> Exportacao de faturamento
# -> BigQuery export -> Editar configuracoes -> selecionar o dataset
# "billing_export" criado aqui. Exige papel "Administrador de conta de
# faturamento" na billing account (diferente do "Gerente de custos" ja
# concedido no passo 5 do README, que so cobre orcamentos).
resource "google_bigquery_dataset" "billing_export" {
  project     = var.project_id
  dataset_id  = "billing_export"
  location    = "US" # multi-regiao - padrao recomendado pelo Google pra billing export
  description = "Exportacao do Cloud Billing (custo detalhado) - alimenta consultas de FinOps. Ver infra/bootstrap/README.md."

  depends_on = [google_project_service.bootstrap_apis]
}

# Bucket para o state remoto do Terraform usado pelos ambientes (fase 1+)
resource "google_storage_bucket" "tf_state" {
  name                        = var.state_bucket_name
  project                     = var.project_id
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.bootstrap_apis]
}

# Service account que o GitHub Actions assume via Workload Identity Federation
# (sem chaves JSON estaticas)
resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = var.github_actions_sa_name
  display_name = "GitHub Actions - Terraform Deployer"

  depends_on = [google_project_service.bootstrap_apis]
}

# Papeis minimos para o pipeline provisionar a infra deste projeto.
# O papel de billing (para o modulo de budget) e concedido separadamente
# na billing account, fora do escopo de IAM do projeto - veja o README.
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin", # firewall rules ficam de fora do networkAdmin de proposito
    "roles/artifactregistry.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/monitoring.editor",
    "roles/logging.admin",
    "roles/pubsub.admin",                    # topico de alertas do modulo budget + fila da fase 8
    "roles/iam.serviceAccountAdmin",         # criar a GSA de Workload Identity do GKE (fase 8) e seu binding
    "roles/resourcemanager.projectIamAdmin", # conceder roles de projeto a essa GSA nova
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Workload Identity Pool para autenticacao OIDC do GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"

  depends_on = [google_project_service.bootstrap_apis]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Aceita tokens de qualquer repo do mesmo usuario/org - a restricao
  # por repositorio especifico e feita no binding de cada service account,
  # nao aqui. Isso permite adicionar novos repos de app sem precisar
  # re-aplicar o bootstrap a cada vez.
  attribute_condition = "assertion.repository_owner == \"${var.github_org}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Permite que workflows deste repositorio assumam a service account acima
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
