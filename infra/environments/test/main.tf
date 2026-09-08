locals {
  required_apis = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "billingbudgets.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "cloudtrace.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "../../modules/network"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name

  depends_on = [google_project_service.apis]
}

module "gke" {
  source = "../../modules/gke"

  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  cluster_name         = var.cluster_name
  network_self_link    = module.network.network_self_link
  subnetwork_self_link = module.network.subnet_self_link
  pods_range_name      = module.network.pods_range_name
  services_range_name  = module.network.services_range_name
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = "sample-app"

  depends_on = [google_project_service.apis]
}

module "budget" {
  source = "../../modules/budget"

  project_id           = var.project_id
  project_number       = var.project_number
  billing_account_id   = var.billing_account_id
  budget_amount        = var.budget_amount
  budget_currency_code = var.budget_currency_code
  enable_budget_alert  = var.enable_budget_alert

  depends_on = [google_project_service.apis]
}

# Um app so tem metricas HTTP (5xx/latencia) se expuser /metrics via
# PodMonitoring - hoje so o podinfo tem isso (ver
# observability/podmonitoring.yaml). Os 4 microsservicos ainda nao
# foram instrumentados com Prometheus (so tracing via Cloud Trace, fase
# 8.2), entao ficam so com os sinais nativos do GKE (restart/CPU/memoria).
module "observability_podinfo" {
  source = "../../modules/observability"

  project_id     = var.project_id
  cluster_name   = var.cluster_name
  app_label      = "podinfo"
  pod_name_regex = "podinfo-.*"

  depends_on = [module.gke]
}

module "observability_microservices" {
  source = "../../modules/observability"

  project_id          = var.project_id
  cluster_name        = var.cluster_name
  app_label           = "microservices"
  pod_name_regex      = "(gateway|service-api|service-worker|service-downstream)-.*"
  enable_http_metrics = false

  depends_on = [module.gke]
}

# Identidade do GCP para os pods do fluxo de microsservicos (fase 8.1)
# publicarem/consumirem do Pub/Sub sem credencial estatica. Usada por
# service-api e service-worker, os unicos que falam com o Pub/Sub - a
# fase 8.2 adiciona roles/cloudtrace.agent aqui tambem, ja que esses
# dois tambem exportam trace.
module "microservices_workload_identity" {
  source = "../../modules/workload-identity"

  project_id     = var.project_id
  gsa_account_id = "microservices-workload"
  ksa_name       = "microservices-ksa"
  namespace      = "default"
  roles = [
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/cloudtrace.agent",
  ]

  depends_on = [module.gke, google_project_service.apis]
}

# Identidade separada (fase 8.2) so para gateway e service-downstream:
# eles nao falam com o Pub/Sub, entao nao ganham as roles de
# publisher/subscriber da GSA acima - least privilege, cada servico com
# so o que sua funcao exige (mesmo principio ja seguido no resto do
# projeto).
module "microservices_trace_workload_identity" {
  source = "../../modules/workload-identity"

  project_id     = var.project_id
  gsa_account_id = "microservices-trace"
  ksa_name       = "microservices-trace-ksa"
  namespace      = "default"
  roles = [
    "roles/cloudtrace.agent",
  ]

  depends_on = [module.gke, google_project_service.apis]
}

# =============================================================================
# BuscaCEP — identidade de runtime dos pods
# Publisher (API) e subscriber (worker) compartilham a mesma KSA; roles
# distintas ficam no escopo de projeto, nao por topico, o que e suficiente
# para um ambiente de teste com um unico projeto.
# =============================================================================
module "buscacep_workload_identity" {
  source = "../../modules/workload-identity"

  project_id     = var.project_id
  gsa_account_id = "buscacep-workload"
  ksa_name       = "buscacep-ksa"
  namespace      = "default"
  roles = [
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
  ]

  depends_on = [module.gke, google_project_service.apis]
}

# =============================================================================
# BuscaCEP — Pub/Sub
# Topico principal + subscription com dead-letter + DLQ propria.
# A DLQ e um cenario de falha intencional para o agente AIOps: quando
# mensagens excedem max_delivery_attempts elas sao redirecionadas para
# cep-consultado-dlq, que pode ser monitorado pelo oldest_unacked_message_age.
# =============================================================================
resource "google_pubsub_topic" "buscacep" {
  project = var.project_id
  name    = "cep-consultado"

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic" "buscacep_dlq" {
  project = var.project_id
  name    = "cep-consultado-dlq"

  depends_on = [google_project_service.apis]
}

resource "google_pubsub_subscription" "buscacep" {
  project = var.project_id
  name    = "cep-consultado-sub"
  topic   = google_pubsub_topic.buscacep.name

  ack_deadline_seconds       = 20
  message_retention_duration = "600s" # 10 min — mensagens nao consumidas somem logo

  dead_letter_policy {
    # .id retorna o nome completo do recurso (projects/{proj}/topics/{name}),
    # exigido pela API. .name retorna apenas o nome curto e causa erro 400.
    dead_letter_topic     = google_pubsub_topic.buscacep_dlq.id
    max_delivery_attempts = 5
  }

  depends_on = [google_pubsub_topic.buscacep, google_pubsub_topic.buscacep_dlq]
}

resource "google_pubsub_subscription" "buscacep_dlq" {
  project              = var.project_id
  name                 = "cep-consultado-dlq-sub"
  topic                = google_pubsub_topic.buscacep_dlq.name
  ack_deadline_seconds = 60

  depends_on = [google_pubsub_topic.buscacep_dlq]
}

# O agente de servico do Pub/Sub precisa publicar na DLQ quando uma mensagem
# excede max_delivery_attempts — sem este binding a dead-letter policy e
# ignorada silenciosamente.
resource "google_pubsub_topic_iam_member" "pubsub_sa_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.buscacep_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# =============================================================================
# BuscaCEP — observabilidade
# Mesmas metricas HTTP (5xx/latencia) que o podinfo; o worker nao expoe
# /metrics entao nao tem PodMonitoring proprio — so os sinais nativos do GKE.
# =============================================================================
module "observability_buscacep" {
  source = "../../modules/observability"

  project_id     = var.project_id
  cluster_name   = var.cluster_name
  app_label      = "buscacep-api"
  pod_name_regex = "buscacep-api-.*"

  depends_on = [module.gke]
}

# =============================================================================
# apps-deploy — GSA compartilhada para os repos de app fazerem CI/CD
# Cada repo de app recebe um binding WIF proprio nesta GSA; o acesso nao
# se expande automaticamente para novos repos — e necessario adicionar
# um google_service_account_iam_member por repo novo.
# =============================================================================
resource "google_service_account" "apps_deploy" {
  project      = var.project_id
  account_id   = "apps-deploy"
  display_name = "Apps Deploy — CI/CD dos repos de aplicacao"
}

resource "google_project_iam_member" "apps_deploy_roles" {
  for_each = toset([
    "roles/artifactregistry.writer", # push de imagens no AR
    "roles/container.developer",     # kubectl apply no cluster
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.apps_deploy.email}"
}

# Binding WIF para o repo IA-App-GCP-Project-01 (BuscaCEP e futuras apps
# neste repo). Para cada novo repo de app, adicionar um bloco analogo.
resource "google_service_account_iam_member" "apps_deploy_wif_app01" {
  service_account_id = google_service_account.apps_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/luiarantes/IA-App-GCP-Project-01"
}
