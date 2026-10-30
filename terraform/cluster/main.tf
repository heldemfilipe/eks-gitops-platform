# Com a rede aplicada de verdade (rede_do_state = true), as saídas vêm do state da camada network.
# Como nada é aplicado neste projeto, o padrão é usar os marcadores de var.rede.
data "terraform_remote_state" "network" {
  count = var.rede_do_state ? 1 : 0

  backend = "local"

  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

locals {
  rede = var.rede_do_state ? data.terraform_remote_state.network[0].outputs : var.rede
}

#trivy:ignore:AWS-0040 endpoint público restrito a admin_cidrs: um cluster privado exigiria bastion ou VPN
#trivy:ignore:AWS-0041 o CIDR é validado em variables.tf para nunca ser 0.0.0.0/0
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = local.rede.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = local.rede.vpc_id
  subnet_ids = local.rede.private_subnet_ids

  # Acesso por access entries, não pelo ConfigMap aws-auth.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.admin_cidrs

  addons = {
    # Os que precisam existir antes dos nós ficam em before_compute.
    vpc-cni = {
      before_compute = true
      # Sem isso a NetworkPolicy é aceita pela API e ignorada pelo CNI.
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
  }

  eks_managed_node_groups = {
    spot = {
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "SPOT"
      instance_types = var.node_instance_types

      min_size     = var.node_desired_size
      max_size     = var.node_desired_size + 1
      desired_size = var.node_desired_size
    }
  }
}
