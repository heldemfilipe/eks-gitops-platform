# Identidade dos pods por EKS Pod Identity: uma role por conta de serviço, com permissão mínima.
# Código validado e testado offline; nunca aplicado na AWS.

data "aws_caller_identity" "current" {}

locals {
  # Pod Identity usa o princípio pods.eks.amazonaws.com e exige sts:TagSession (a IRSA usa o OIDC do cluster).
  pod_identity_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  # O ESO só lê os segredos do prefixo do laboratório.
  eso_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}*"
    }]
  })
}

# --- AWS Load Balancer Controller ---

resource "aws_iam_role" "lbc" {
  name               = "${module.eks.cluster_name}-lbc"
  assume_role_policy = local.pod_identity_trust
}

# Policy oficial do projeto aws-load-balancer-controller v3.6.2 (docs/install/iam_policy.json), sem alterações.
# Tem Resource "*" em ações de leitura do EC2/ELB; é o formato que o controller exige.
resource "aws_iam_policy" "lbc" {
  name   = "${module.eks.cluster_name}-lbc"
  policy = file("${path.module}/policies/lbc-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

# --- External Secrets Operator ---

resource "aws_iam_role" "eso" {
  name               = "${module.eks.cluster_name}-external-secrets"
  assume_role_policy = local.pod_identity_trust
}

resource "aws_iam_role_policy" "eso" {
  name   = "ler-segredos-do-laboratorio"
  role   = aws_iam_role.eso.id
  policy = local.eso_policy
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}
