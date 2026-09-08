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
