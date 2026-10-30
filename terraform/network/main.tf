# Um único NAT gateway para as duas zonas: cerca de US$ 0,045 por hora (valor a reconfirmar na página de
# preços). Alternativa: um NAT por zona, que sobrevive à queda de uma zona e custa o dobro.
module "network" {
  source = "git::https://github.com/heldemfilipe/terraform-aws-foundation.git//modules/network?ref=v1.2.0"

  nome               = var.nome
  azs                = var.azs
  enable_nat_gateway = var.enable_nat_gateway

  # O AWS Load Balancer Controller descobre as sub-redes por estas tags.
  public_subnet_tags = {
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.nome}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"   = "1"
    "kubernetes.io/cluster/${var.nome}" = "shared"
  }
}
