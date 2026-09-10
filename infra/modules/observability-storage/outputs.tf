output "loki_bucket_name" {
  description = "Nome do bucket GCS para chunks do Loki"
  value       = google_storage_bucket.loki_chunks.name
}

output "tempo_bucket_name" {
  description = "Nome do bucket GCS para traces do Tempo"
  value       = google_storage_bucket.tempo_traces.name
}

output "storage_service_account_email" {
  description = "Email da GSA associada ao Workload Identity para telemetria"
  value       = google_service_account.grafana_storage.email
}
