output "argocd_chart_version" {
  description = "Versão do chart instalada."
  value       = helm_release.argocd.version
}

output "argocd_namespace" {
  description = "Namespace do Argo CD."
  value       = helm_release.argocd.namespace
}
