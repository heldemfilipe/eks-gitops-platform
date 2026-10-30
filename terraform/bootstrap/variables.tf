variable "kubeconfig_path" {
  description = "Caminho do kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexto do kubeconfig. Só contextos do kind são aceitos, para esta camada nunca tocar um cluster real."
  type        = string
  default     = "kind-lab"

  validation {
    condition     = startswith(var.kube_context, "kind-")
    error_message = "Esta camada só instala no kind (contexto kind-<nome>). Recusado para não tocar um cluster real."
  }
}

variable "argocd_chart_version" {
  description = "Versão do chart argo-cd. A 10.11.6 instala o Argo CD v3.5.6, a mesma do laboratório da Etapa 1."
  type        = string
  default     = "10.11.6"
}
