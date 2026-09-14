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

variable "grafana_stack_mode" {
  description = "Modo de operação da stack Grafana Labs: 'simple' (monolítico leve) ou 'distributed' (microsserviços HA com GCS)"
  type        = string
  default     = "simple"
  validation {
    condition     = contains(["simple", "distributed"], var.grafana_stack_mode)
    error_message = "O valor de grafana_stack_mode deve ser 'simple' ou 'distributed'."
  }
}

variable "enable_gpu_pool" {
  description = "Habilita o node pool dedicado com GPU Spot para inferência privada dos agentes AIOps"
  type        = bool
  default     = true
}

variable "gpu_type" {
  description = "Tipo de acelerador GPU a ser alocado (padrão: nvidia-tesla-t4)"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_machine_type" {
  description = "Tipo de máquina para o nó de GPU (padrão: n1-standard-4)"
  type        = string
  default     = "n1-standard-4"
}
