variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região GCP para os buckets de telemetria"
  type        = string
  default     = "us-central1"
}
