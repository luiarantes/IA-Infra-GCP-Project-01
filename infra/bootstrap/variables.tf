variable "project_id" {
  description = "ID do projeto GCP onde o bootstrap sera criado"
  type        = string
}

variable "region" {
  description = "Regiao padrao para os recursos"
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Nome globalmente unico do bucket GCS para o state remoto do Terraform"
  type        = string
}

variable "github_org" {
  description = "Organizacao ou usuario do GitHub dono do repositorio"
  type        = string
}

variable "github_repo" {
  description = "Nome do repositorio no GitHub"
  type        = string
}

variable "github_actions_sa_name" {
  description = "Nome da service account usada pelo GitHub Actions via Workload Identity Federation"
  type        = string
  default     = "github-actions-deployer"
}
