# Identidade do GCP usada pelos pods (nao pelo pipeline de CI - esse ja
# tem sua propria WIF criada em infra/bootstrap). Workload Identity do
# GKE permite que uma ServiceAccount do Kubernetes (KSA) se autentique
# como essa GSA sem nenhuma chave estatica, similar em espirito ao WIF
# do GitHub Actions, mas para workloads dentro do cluster.
resource "google_service_account" "workload" {
  project      = var.project_id
  account_id   = var.gsa_account_id
  display_name = "Workload Identity - ${var.gsa_account_id}"
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.workload.email}"
}

# Binding que autoriza a KSA especifica (namespace/nome) a agir como
# essa GSA - sem isso, a annotation no manifesto do Kubernetes sozinha
# nao concede nada.
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.workload.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"
}
