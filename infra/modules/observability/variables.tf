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
