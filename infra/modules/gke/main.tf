# Cluster GKE Standard Zonal com nó SPOT (Preemptible):
# - Control Plane Zonal coberto pela franquia gratuita de US$ 74/mes da GCP
# - Instâncias SPOT e2-standard-2 (2 vCPU, 8GB RAM) com custo ~US$ 0,015/h (~R$ 0,08/h)
# - Paridade direta 1:1 com Managed Node Groups do AWS EKS
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone

  # Remove pool padrão para gerenciar nós via recurso dedicado google_container_node_pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Precisa ser false para permitir `terraform destroy` sem passo manual
  deletion_protection = false
}

resource "google_container_node_pool" "spot_nodes" {
  name       = "spot-node-pool"
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    spot         = true
    machine_type = var.machine_type
    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      environment = "gcp-gke-spot"
    }

    tags = ["gke-node", "aiops-node"]
  }
}
