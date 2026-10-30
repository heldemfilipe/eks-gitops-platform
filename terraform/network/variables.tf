variable "region" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-1"
}

variable "nome" {
  description = "Prefixo dos recursos e nome do cluster que usará esta rede."
  type        = string
  default     = "eks-lab"
}

variable "azs" {
  description = "Zonas de disponibilidade. O EKS exige pelo menos duas."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "O EKS exige sub-redes em pelo menos duas zonas de disponibilidade."
  }
}

variable "enable_nat_gateway" {
  description = "Liga o NAT gateway. Os nós ficam em sub-redes privadas e precisam dele para sair para a internet."
  type        = bool
  default     = true
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
