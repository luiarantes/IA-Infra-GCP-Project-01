output "log_metric_name" {
  value = google_logging_metric.app_errors.name
}

output "alert_policy_name" {
  value = google_monitoring_alert_policy.app_error_rate.name
}

output "restart_alert_policy_name" {
  value = google_monitoring_alert_policy.container_restarts.name
}

output "cpu_alert_policy_name" {
  value = google_monitoring_alert_policy.high_cpu.name
}

output "memory_alert_policy_name" {
  value = google_monitoring_alert_policy.high_memory.name
}

output "http_5xx_alert_policy_name" {
  value = var.enable_http_metrics ? google_monitoring_alert_policy.http_5xx_errors[0].name : null
}

output "latency_alert_policy_name" {
  value = var.enable_http_metrics ? google_monitoring_alert_policy.high_latency[0].name : null
}
