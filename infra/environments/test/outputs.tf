output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "network_name" {
  value = module.network.network_name
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "microservices_workload_gsa_email" {
  value = module.microservices_workload_identity.gsa_email
}

output "microservices_trace_gsa_email" {
  value = module.microservices_trace_workload_identity.gsa_email
}
