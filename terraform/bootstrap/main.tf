# Repositório e cache do Helm isolados em .helm/: o provider não depende de `helm repo add` nem do que já está
# no Helm do usuário (um índice em cache faltando quebrava o apply).
provider "helm" {
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  repository_cache       = "${path.module}/.helm/cache"

  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

# Só o Argo CD vem do Terraform. Todo o resto do cluster vem do Git (eks-gitops-config), a partir do
# root.yaml aplicado pelo Makefile com kubectl: kubernetes_manifest exigiria o CRD já instalado no plan.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  wait    = true
  timeout = 600

  # Enxuto para o laboratório: sem login por SSO e sem notificações.
  values = [yamlencode({
    dex           = { enabled = false }
    notifications = { enabled = false }
  })]
}
