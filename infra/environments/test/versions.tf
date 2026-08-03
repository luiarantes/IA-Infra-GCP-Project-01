terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }

  # bucket e prefix sao passados via -backend-config no `terraform init`
  # (valores vem dos outputs do infra/bootstrap - veja o workflow do CI)
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}
