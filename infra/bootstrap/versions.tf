terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # State local de propósito: este bootstrap roda uma única vez, manualmente,
  # antes de existir o bucket remoto que os demais ambientes vão usar.
}

provider "google" {
  project = var.project_id
  region  = var.region
}
