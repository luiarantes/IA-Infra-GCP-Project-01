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
