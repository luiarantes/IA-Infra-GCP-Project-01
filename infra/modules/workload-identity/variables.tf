variable "project_id" {
  type = string
}

variable "gsa_account_id" {
  description = "Account ID (parte local do e-mail) da service account do GCP a ser criada"
  type        = string
}

variable "ksa_name" {
  description = "Nome da ServiceAccount do Kubernetes que vai se autenticar como essa GSA"
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes onde a KSA vive"
  type        = string
  default     = "default"
}

variable "roles" {
  description = "Roles de projeto concedidas a GSA (ex: roles/pubsub.publisher)"
  type        = list(string)
  default     = []
}
