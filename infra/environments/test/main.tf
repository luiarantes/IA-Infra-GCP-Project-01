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

module "observability" {
  source = "../../modules/observability"

  project_id   = var.project_id
  cluster_name = var.cluster_name

  depends_on = [module.gke]
}

# Identidade do GCP para os pods do fluxo de microsservicos (fase 8.1)
# publicarem/consumirem do Pub/Sub sem credencial estatica. A GSA
# ganha so os papeis que o fluxo precisa hoje; a fase 8.2 (tracing)
# reaproveita essa mesma GSA adicionando roles/cloudtrace.agent, em vez
# de criar uma identidade nova.
module "microservices_workload_identity" {
  source = "../../modules/workload-identity"

  project_id     = var.project_id
  gsa_account_id = "microservices-workload"
  ksa_name       = "microservices-ksa"
  namespace      = "default"
  roles = [
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
  ]

  depends_on = [module.gke, google_project_service.apis]
}
