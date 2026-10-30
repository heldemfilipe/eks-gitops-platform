mock_provider "helm" {}

run "contexto_do_kind_e_aceito" {
  command = plan

  assert {
    condition     = helm_release.argocd.namespace == "argocd" && helm_release.argocd.version == "10.11.6"
    error_message = "O Argo CD deve ir para o namespace argocd na versão fixada do chart."
  }
}

run "contexto_de_cluster_real_e_recusado" {
  command = plan

  variables {
    kube_context = "arn:aws:eks:us-east-1:123456789012:cluster/producao"
  }

  expect_failures = [var.kube_context]
}
