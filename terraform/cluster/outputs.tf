output "cluster_name" {
  description = "Nome do cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA do cluster, em base64."
  value       = module.eks.cluster_certificate_authority_data
}
