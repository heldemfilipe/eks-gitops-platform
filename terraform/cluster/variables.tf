variable "region" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes no EKS. Use a mais nova em suporte padrão: versão antiga entra em suporte estendido (US$ 0,60 por hora no plano de controle)."
  type        = string
  default     = "1.37" # a confirmar na página de versões do EKS antes de qualquer uso real

  validation {
    condition     = can(regex("^1[.][0-9]{2}$", var.kubernetes_version))
    error_message = "Use o formato <major>.<minor>, por exemplo 1.37."
  }
}

variable "admin_cidrs" {
  description = "CIDRs que podem falar com o endpoint público do EKS. Use o seu IP; nunca 0.0.0.0/0."
  type        = list(string)
  default     = ["203.0.113.10/32"] # faixa de documentação (TEST-NET-3), não é um IP real

  validation {
    condition     = length(var.admin_cidrs) > 0 && !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "Informe ao menos um CIDR e não libere 0.0.0.0/0 no endpoint do cluster."
  }
}

variable "node_instance_types" {
  description = "Tipos de instância dos nós. t3.medium limita ~17 pods por nó (ENI); t3.large cabe Argo CD, Prometheus, Kyverno e a API."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_desired_size" {
  description = "Quantidade de nós desejada."
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired_size >= 2
    error_message = "Use ao menos 2 nós: o PodDisruptionBudget e o drain da Etapa 6 dependem disso."
  }
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos."
  type        = map(string)
  default = {
    Project     = "eks-gitops-platform"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

variable "rede_do_state" {
  description = "Lê VPC e sub-redes do state da camada network (terraform_remote_state). Falso por padrão porque a rede nunca é aplicada: sem state, os valores vêm de var.rede."
  type        = bool
  default     = false
}

variable "rede" {
  description = "Marcadores da rede, usados só quando rede_do_state é falso (modo offline)."
  type = object({
    vpc_id             = string
    private_subnet_ids = list(string)
    cluster_name       = string
  })
  default = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    cluster_name       = "eks-lab"
  }
}

variable "secrets_prefix" {
  description = "Prefixo dos segredos do Secrets Manager que o External Secrets pode ler. Termina em barra."
  type        = string
  default     = "eks-lab/"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*/$", var.secrets_prefix))
    error_message = "Use um prefixo como eks-lab/ (sem curinga e terminado em barra)."
  }
}
