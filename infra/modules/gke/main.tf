# Cluster GKE Autopilot: cobra por pod usado (nao por VM ociosa) e o GCP
# oferece 1 cluster zonal Autopilot gratuito por conta de billing - ideal
# para o ciclo criar -> testar -> destruir deste projeto.
resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  enable_autopilot = true

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = "REGULAR"
  }

  # Precisa ser false para permitir `terraform destroy` sem passo manual
  deletion_protection = false
}
