# Ambiente AWS EKS (Scaffold Multi-Cloud)

Este diretório contém a estrutura de Infraestrutura como Código (Terraform) preparada para o provisionamento da plataforma no provedor **Amazon Web Services (AWS)** utilizando **Amazon EKS** com instâncias **Spot EC2** e mensageria **Amazon SQS/SNS**.

---

## 🏗️ Arquitetura Alvo na AWS

```
  AWS Cloud
  ├── VPC (aws_vpc, subnets públicas/privadas, IGW, NAT Gateway)
  ├── IAM (OIDC Provider + IAM Roles for Service Accounts / IRSA)
  ├── Amazon EKS Cluster (aws_eks_cluster)
  │   └── Managed Node Group (aws_eks_node_group com capacity_type = "SPOT")
  │       ├── 1x t3.medium ou c6i.large (Spot ~US$ 0,016/h)
  │       └── EBS CSI Driver (StorageClass gp3 para o OpenObserve)
  ├── Amazon SQS / SNS (Fila assíncrona equivalente ao Pub/Sub)
  └── Amazon ECR (Registro de containers para imagens dos microsserviços)
```

---

## 🔄 Paridade com os Ambientes Local e GCP

| Componente | Ambiente Local | Ambiente GCP | Ambiente AWS (Este Módulo) |
|---|---|---|---|
| **IaC** | `infra/environments/local` | `infra/environments/gcp` (ou `test`) | `infra/environments/aws` |
| **Cluster K8s** | Kind (Docker) | GKE Standard Zonal (Spot) | AWS EKS (Managed Spot Nodes) |
| **Storage Class** | `standard` (hostPath) | `standard` (pd-standard) | `gp3` (EBS) |
| **Identidade** | Mock / Env Vars | Workload Identity (WIF) | EKS Pod Identity / IRSA |
| **Observabilidade** | OTel + OpenObserve | OTel + OpenObserve | OTel + OpenObserve |

---

## 🚀 Como Ativar futuramente

Quando formos executar a camada AWS:
1. Configurar credenciais AWS CLI (`aws configure`).
2. Definir as variáveis em `terraform.tfvars` (`aws_region = "us-east-1"`, `cluster_name = "aiops-eks"`).
3. Executar `terraform init && terraform apply`.
