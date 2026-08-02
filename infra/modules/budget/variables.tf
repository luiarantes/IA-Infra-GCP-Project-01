variable "project_id" {
  type = string
}

variable "project_number" {
  description = "Numero (nao o ID) do projeto GCP, usado no filtro do orcamento"
  type        = string
}

variable "billing_account_id" {
  type = string
}

variable "budget_display_name" {
  type    = string
  default = "aiops-test-budget"
}

variable "budget_amount" {
  description = "Teto do orcamento, na moeda de budget_currency_code"
  type        = number
  default     = 250
}

variable "budget_currency_code" {
  description = "Codigo ISO 4217 da moeda - precisa bater com a moeda da billing account (gcloud billing accounts describe <id> --format='value(currencyCode)')"
  type        = string
  default     = "BRL"
}

variable "alert_thresholds" {
  description = "Percentuais do orcamento que disparam alerta (0.5 = 50%)"
  type        = list(number)
  default     = [0.5, 0.8, 1.0]
}

variable "enable_budget_alert" {
  description = "Desative se a SA nao tiver permissao na billing account; configure o orcamento manualmente no Console nesse caso"
  type        = bool
  default     = true
}
