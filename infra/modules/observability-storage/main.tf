resource "google_storage_bucket" "loki_chunks" {
  name                        = "${var.project_id}-loki-chunks"
  project                     = var.project_id
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 1 # Efêmero: limpa dados antigos após 1 dia
    }
  }
}

resource "google_storage_bucket" "tempo_traces" {
  name                        = "${var.project_id}-tempo-traces"
  project                     = var.project_id
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 1 # Efêmero: limpa dados antigos após 1 dia
    }
  }
}

resource "google_service_account" "grafana_storage" {
  account_id   = "grafana-storage-sa"
  display_name = "Service Account para Loki e Tempo no Cloud Storage"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "loki_storage" {
  bucket = google_storage_bucket.loki_chunks.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.grafana_storage.email}"
}

resource "google_storage_bucket_iam_member" "tempo_storage" {
  bucket = google_storage_bucket.tempo_traces.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.grafana_storage.email}"
}

# Workload Identity: permite que as KSAs default/loki e default/tempo assumam a GSA
resource "google_service_account_iam_member" "loki_workload_identity" {
  service_account_id = google_service_account.grafana_storage.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/loki]"
}

resource "google_service_account_iam_member" "tempo_workload_identity" {
  service_account_id = google_service_account.grafana_storage.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/tempo]"
}
