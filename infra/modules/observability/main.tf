# Metrica baseada em log: conta entradas de severidade ERROR+ vindas dos
# containers do cluster. E gratis (Cloud Logging/Monitoring tem free tier
# generoso) e fica versionada como codigo, em vez de configurada no Console.
#
# Limitacao conhecida: isso so funciona se a aplicacao usar o campo JSON
# "severity" (convencao da GCP) ou nao usar logging estruturado nenhum. O
# podinfo, por exemplo, usa "level" (convencao da lib Zap) - o Cloud
# Logging nao promove isso automaticamente, entao os logs dele sempre
# chegam como severity=DEFAULT/INFO, mesmo em cenarios de falha. Por isso
# o alerta de restart_count abaixo existe: e um sinal de plataforma
# (Kubernetes), nao depende de como cada app loga.
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

# Alerta baseado em sinal de plataforma (nao de aplicacao): dispara sempre
# que algum container reinicia, via a metrica nativa do GKE
# kubernetes.io/container/restart_count. Funciona independente de como a
# app loga - e o sinal que os agentes de self-healing (fase 5+) vao
# realmente usar para detectar crash loops como o testado manualmente
# com o endpoint /panic do podinfo.
resource "google_monitoring_alert_policy" "container_restarts" {
  project      = var.project_id
  display_name = "${var.app_label}: container reiniciou"
  combiner     = "OR"

  conditions {
    display_name = "restart_count aumentou nos ultimos 5 minutos"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.cluster_name}\" AND resource.labels.namespace_name=\"${var.namespace}\" AND metric.type=\"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.restart_threshold
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
