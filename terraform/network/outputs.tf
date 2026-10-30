output "vpc_id" {
  description = "ID da VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das sub-redes públicas."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs das sub-redes privadas, onde ficam os nós."
  value       = module.network.private_subnet_ids
}

output "cluster_name" {
  description = "Nome do cluster para o qual as sub-redes foram etiquetadas."
  value       = var.nome
}
