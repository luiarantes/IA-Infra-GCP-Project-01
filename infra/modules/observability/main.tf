# Metrica baseada em log: conta entradas de severidade ERROR+ vindas dos
# containers do cluster. E gratis (Cloud Logging/Monitoring tem free tier
# generoso) e fica versionada como codigo, em vez de configurada no Console.
resource "google_logging_metric" "app_errors" {
  project = var.project_id
  name    = "${var.app_label}-error-count"
  filter  = <<-EOT
    resource.type="k8s_container"
    resource.labels.cluster_name="${var.cluster_name}"
    resource.labels.namespace_name="${var.namespace}"
    severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# Alerta quando a taxa de erro passa do limite numa janela de 5 minutos.
# Sem notification_channels de proposito no MVP - o objetivo aqui e o
# agente de IA (fase 5) consultar essa politica via API, nao mandar email.
resource "google_monitoring_alert_policy" "app_error_rate" {
  project      = var.project_id
  display_name = "${var.app_label}: taxa de erro elevada"
  combiner     = "OR"

  conditions {
    display_name = "logs de erro nos ultimos 5 minutos"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.app_errors.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
