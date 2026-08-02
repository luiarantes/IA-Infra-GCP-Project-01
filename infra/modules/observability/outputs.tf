output "log_metric_name" {
  value = google_logging_metric.app_errors.name
}

output "alert_policy_name" {
  value = google_monitoring_alert_policy.app_error_rate.name
}
