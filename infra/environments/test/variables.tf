variable "cloud_provider" {
  description = "Provedor de nuvem alvo (gcp | aws)"
  type        = string
  default     = "gcp"
  validation {
    condition     = contains(["gcp", "aws"], var.cloud_provider)
    error_message = "O cloud_provider deve ser 'gcp' ou 'aws'."
  }
}

variable "project_id" {
  type = string
}

variable "project_number" {
  description = "Numero do projeto, usado pelo filtro do orcamento"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  description = "Zona para o cluster GKE Standard Zonal (coberto pelo free tier)"
  type        = string
  default     = "us-central1-a"
}

variable "billing_account_id" {
  type = string
}

variable "network_name" {
  type    = string
  default = "aiops-vpc"
}

variable "cluster_name" {
  type    = string
  default = "aiops-gke"
}

variable "budget_amount" {
  type    = number
  default = 250
}

variable "budget_currency_code" {
  type    = string
  default = "BRL"
}

variable "enable_budget_alert" {
  type    = bool
  default = true
}
