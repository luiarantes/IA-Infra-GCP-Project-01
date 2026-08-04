variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  description = "Namespace Kubernetes onde o app roda"
  type        = string
  default     = "default"
}

variable "app_label" {
  description = "Nome curto usado para prefixar a metrica e o alerta (so aparece no nome/display_name - quem filtra de verdade e' pod_name_regex)"
  type        = string
  default     = "sample-app"
}

variable "pod_name_regex" {
  description = "Regex (usado com monitoring.regex.full_match / Cloud Logging =~) que casa com resource.labels.pod_name dos pods deste app - evita que o mesmo evento conte pra alertas de apps diferentes quando o modulo e instanciado mais de uma vez no mesmo namespace"
  type        = string
}

variable "enable_http_metrics" {
  description = "Cria os alertas de http_5xx/latencia, que dependem do app expor metricas Prometheus via PodMonitoring - desative para apps sem essa instrumentacao"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "Quantidade de logs de erro na janela que dispara o alerta"
  type        = number
  default     = 0
}

variable "restart_threshold" {
  description = "Quantidade de restarts na janela de 5min que dispara o alerta"
  type        = number
  default     = 0
}

variable "cpu_utilization_threshold" {
  description = "Fracao (0.0-1.0) do limite de CPU que dispara o alerta"
  type        = number
  default     = 0.8
}

variable "memory_utilization_threshold" {
  description = "Fracao (0.0-1.0) do limite de memoria que dispara o alerta"
  type        = number
  default     = 0.8
}

variable "http_5xx_rate_threshold" {
  description = "Taxa de erros 5xx/segundo que dispara o alerta"
  type        = number
  default     = 0
}

variable "latency_p95_threshold_seconds" {
  description = "Latencia p95 (segundos) que dispara o alerta"
  type        = number
  default     = 1
}
