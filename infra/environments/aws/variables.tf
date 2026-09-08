variable "cloud_provider" {
  description = "Provedor de nuvem alvo (gcp | aws)"
  type        = string
  default     = "aws"
}

variable "aws_region" {
  description = "Regiao AWS para o provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster Amazon EKS"
  type        = string
  default     = "aiops-eks"
}

variable "node_instance_type" {
  description = "Tipo de instancia EC2 Spot para o Node Group"
  type        = string
  default     = "t3.medium"
}
