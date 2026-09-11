provider "kind" {}

resource "kind_cluster" "default" {
  name           = var.cluster_name
  node_image     = var.node_image
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = var.gateway_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30000
        host_port      = var.buscacep_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30580
        host_port      = var.openobserve_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30085
        host_port      = var.pubsub_emulator_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30300
        host_port      = var.grafana_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30440
        host_port      = var.pyroscope_port
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 30901
        host_port      = var.minio_port
        protocol       = "TCP"
      }
    }
  }
}

resource "null_resource" "deploy_local_workloads" {
  depends_on = [kind_cluster.default]

  triggers = {
    cluster_id = kind_cluster.default.id
    stack_mode = var.grafana_stack_mode
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../../../local/scripts/local-env.sh provision ${var.grafana_stack_mode}"
  }
}

