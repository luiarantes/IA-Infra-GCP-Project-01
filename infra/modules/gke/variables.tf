variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "cluster_name" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "network_self_link" {
  type = string
}

variable "subnetwork_self_link" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 2
}

variable "enable_gpu_pool" {
  description = "Habilita o node pool dedicado com GPU Spot para inferência privada dos agentes AIOps (Requer upgrade de billing na GCP para desbloquear GPUs)"
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "Tipo de acelerador GPU (ex: nvidia-tesla-t4, nvidia-l4)"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_machine_type" {
  description = "Tipo de máquina para o nó de GPU (ex: n1-standard-4 para T4)"
  type        = string
  default     = "n1-standard-4"
}

variable "gpu_node_count" {
  description = "Contagem inicial de nós de GPU"
  type        = number
  default     = 1
}

variable "gpu_min_node_count" {
  description = "Contagem mínima de nós de GPU no autoscaling (0 permite scale-to-zero para FinOps)"
  type        = number
  default     = 0
}

variable "gpu_max_node_count" {
  description = "Contagem máxima de nós de GPU no autoscaling"
  type        = number
  default     = 1
}
