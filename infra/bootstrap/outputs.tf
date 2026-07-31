output "state_bucket_name" {
  description = "Nome do bucket - use como TF_STATE_BUCKET nos secrets do GitHub"
  value       = google_storage_bucket.tf_state.name
}

output "workload_identity_provider" {
  description = "Valor para o secret GCP_WORKLOAD_IDENTITY_PROVIDER no GitHub"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "github_actions_service_account_email" {
  description = "Valor para o secret GCP_SERVICE_ACCOUNT no GitHub"
  value       = google_service_account.github_actions.email
}
