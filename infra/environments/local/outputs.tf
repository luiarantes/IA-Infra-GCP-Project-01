output "cluster_name" {
  description = "Nome do cluster local Kind"
  value       = kind_cluster.default.name
}

output "openobserve_url" {
  description = "URL para acesso a interface web do OpenObserve"
  value       = "http://localhost:${var.openobserve_port}"
}

output "gateway_url" {
  description = "URL do Gateway de microsservicos"
  value       = "http://localhost:${var.gateway_port}"
}

output "buscacep_url" {
  description = "URL da aplicacao BuscaCEP"
  value       = "http://localhost:${var.buscacep_port}"
}

output "pubsub_emulator_url" {
  description = "URL do emulador do Google Pub/Sub"
  value       = "http://localhost:${var.pubsub_emulator_port}"
}

output "grafana_url" {
  description = "URL para acesso a interface web do Grafana OSS"
  value       = "http://localhost:${var.grafana_port}"
}

output "pyroscope_url" {
  description = "URL para acesso a interface web do Pyroscope"
  value       = "http://localhost:${var.pyroscope_port}"
}
