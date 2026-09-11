variable "cluster_name" {
  description = "Nome do cluster local Kind"
  type        = string
  default     = "aiops-local"
}

variable "node_image" {
  description = "Imagem Kind para os nós do Kubernetes"
  type        = string
  default     = "kindest/node:v1.31.0"
}

variable "gateway_port" {
  description = "Porta no host para o Gateway da Infra"
  type        = number
  default     = 8080
}

variable "buscacep_port" {
  description = "Porta no host para a API BuscaCEP"
  type        = number
  default     = 8000
}

variable "openobserve_port" {
  description = "Porta no host para a UI do OpenObserve"
  type        = number
  default     = 5080
}

variable "pubsub_emulator_port" {
  description = "Porta no host para o emulador do Google Pub/Sub"
  type        = number
  default     = 8085
}

variable "grafana_port" {
  description = "Porta no host para a UI do Grafana OSS"
  type        = number
  default     = 3000
}

variable "pyroscope_port" {
  description = "Porta no host para a UI do Pyroscope"
  type        = number
  default     = 4040
}

variable "minio_port" {
  description = "Porta no host para a Console Web do MinIO (Modo Distribuído)"
  type        = number
  default     = 9001
}

variable "grafana_stack_mode" {
  description = "Modo de implantação da stack Grafana Labs: 'simple' (monolítico leve, ~8GB Docker) ou 'distributed' (produção com MinIO S3 Object Storage, ~12GB Docker)"
  type        = string
  default     = "simple"
  validation {
    condition     = contains(["simple", "distributed"], var.grafana_stack_mode)
    error_message = "O valor de grafana_stack_mode deve ser 'simple' ou 'distributed'."
  }
}

