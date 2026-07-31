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

variable "budget_amount_usd" {
  type    = number
  default = 250
}

variable "enable_budget_alert" {
  type    = bool
  default = true
}
