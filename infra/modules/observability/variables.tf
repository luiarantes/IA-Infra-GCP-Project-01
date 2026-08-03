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
  description = "Nome curto usado para prefixar a metrica e o alerta"
  type        = string
  default     = "sample-app"
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
