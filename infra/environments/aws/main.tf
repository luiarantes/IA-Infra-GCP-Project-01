# Provedor AWS configurado para a regiao especificada
provider "aws" {
  region = var.aws_region
}

# Scaffold para provisionamento futuro do Amazon EKS:
# 1. VPC com subnets públicas e privadas
# 2. IAM Roles para o Cluster e Node Group (IRSA)
# 3. aws_eks_cluster
# 4. aws_eks_node_group com capacity_type = "SPOT"
# 5. Fila Amazon SQS para mensageria assíncrona
