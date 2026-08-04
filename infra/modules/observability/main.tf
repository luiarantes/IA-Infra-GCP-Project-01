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
    resource.labels.pod_name=~"^(${var.pod_name_regex})"
    severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# Espera de propagacao: a API do Monitoring pode demorar ate alguns
# minutos para "enxergar" uma metrica de log recem-criada (a propria
# mensagem de erro do Google avisa isso). Sem essa espera, criar a
# alert_policy logo em seguida falha de forma intermitente com
# "Cannot find metric(s) that match type = ...".
resource "time_sleep" "wait_for_metric_propagation" {
  create_duration = "90s"

  depends_on = [google_logging_metric.app_errors]
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

  depends_on = [time_sleep.wait_for_metric_propagation]
}

# Alerta baseado em sinal de plataforma (nao de aplicacao): dispara sempre
# que algum container reinicia, via a metrica nativa do GKE
# kubernetes.io/container/restart_count. Funciona independente de como a
# app loga - e o sinal que os agentes de self-healing (fase 5+) usam pra
# detectar crash loops. Filtrado por resource.labels.pod_name (fase 8.4)
# pra nao misturar restarts de apps diferentes quando o modulo e
# instanciado mais de uma vez no mesmo namespace.
resource "google_monitoring_alert_policy" "container_restarts" {
  project      = var.project_id
  display_name = "${var.app_label}: container reiniciou"
  combiner     = "OR"

  conditions {
    display_name = "restart_count aumentou nos ultimos 5 minutos"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.cluster_name}\" AND resource.labels.namespace_name=\"${var.namespace}\" AND resource.labels.pod_name=monitoring.regex.full_match(\"${var.pod_name_regex}\") AND metric.type=\"kubernetes.io/container/restart_count\""
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

# ---------------------------------------------------------------------
# Alertas adicionais: CPU/memoria alta (metricas nativas do GKE, sempre
# criados) e erros 5xx / latencia (dependem do app expor metricas
# Prometheus via PodMonitoring - so criados se enable_http_metrics=true,
# ja que nem todo app tem essa instrumentacao).
# ---------------------------------------------------------------------

# CPU alta: "limit_utilization" ja vem normalizado (0.0-1.0) pela propria
# GCP, relativo ao resources.limits.cpu do deployment - nao precisa
# calcular a razao manualmente.
resource "google_monitoring_alert_policy" "high_cpu" {
  project      = var.project_id
  display_name = "${var.app_label}: uso de CPU elevado"
  combiner     = "OR"

  conditions {
    display_name = "CPU acima do limite configurado"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.cluster_name}\" AND resource.labels.namespace_name=\"${var.namespace}\" AND resource.labels.pod_name=monitoring.regex.full_match(\"${var.pod_name_regex}\") AND metric.type=\"kubernetes.io/container/cpu/limit_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_utilization_threshold
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# Memoria alta: mesmo raciocinio do CPU, metrica nativa ja normalizada.
resource "google_monitoring_alert_policy" "high_memory" {
  project      = var.project_id
  display_name = "${var.app_label}: uso de memoria elevado"
  combiner     = "OR"

  conditions {
    display_name = "Memoria acima do limite configurado"

    condition_threshold {
      filter          = "resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${var.cluster_name}\" AND resource.labels.namespace_name=\"${var.namespace}\" AND resource.labels.pod_name=monitoring.regex.full_match(\"${var.pod_name_regex}\") AND metric.type=\"kubernetes.io/container/memory/limit_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.memory_utilization_threshold
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# Taxa de erros 5xx: usa PromQL diretamente sobre a metrica http_requests_total
# que o app expoe via PodMonitoring. Tipo de condicao diferente dos
# anteriores (condition_prometheus_query_language, nao condition_threshold).
# So criado se enable_http_metrics=true - nem todo app tem essa metrica
# (ver observability/podmonitoring.yaml, hoje so cobre o podinfo).
resource "google_monitoring_alert_policy" "http_5xx_errors" {
  count = var.enable_http_metrics ? 1 : 0

  project      = var.project_id
  display_name = "${var.app_label}: taxa de erros 5xx"
  combiner     = "OR"

  conditions {
    display_name = "erros 5xx nos ultimos 5 minutos"

    condition_prometheus_query_language {
      query    = "sum(rate(http_requests_total{status=~\"5..\"}[5m])) > ${var.http_5xx_rate_threshold}"
      duration = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# Latencia p95: histogram_quantile precisa de PromQL de verdade - nao da
# pra fazer isso com condition_threshold comum sobre as buckets do
# histograma. Mesma condicao de enable_http_metrics do alerta de 5xx.
resource "google_monitoring_alert_policy" "high_latency" {
  count = var.enable_http_metrics ? 1 : 0

  project      = var.project_id
  display_name = "${var.app_label}: latencia p95 elevada"
  combiner     = "OR"

  conditions {
    display_name = "p95 de latencia acima do limite"

    condition_prometheus_query_language {
      query    = "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > ${var.latency_p95_threshold_seconds}"
      duration = "60s"
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
