# Sem AWS: o provider é um mock. O módulo EKS consulta a conta (STS e partição), por isso estes dados
# têm valores fixos.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/teste"
      user_id    = "AIDATESTE"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/teste"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "plan_com_os_padroes" {
  command = plan

  assert {
    condition     = output.cluster_name == "eks-lab"
    error_message = "O nome do cluster deve vir da rede (marcador eks-lab)."
  }
}

run "endpoint_nao_aceita_0_0_0_0" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "endpoint_exige_ao_menos_um_cidr" {
  command = plan

  variables {
    admin_cidrs = []
  }

  expect_failures = [var.admin_cidrs]
}

run "versao_do_kubernetes_com_formato_invalido" {
  command = plan

  variables {
    kubernetes_version = "1.37.0"
  }

  expect_failures = [var.kubernetes_version]
}

run "menos_de_dois_nos_e_rejeitado" {
  command = plan

  variables {
    node_desired_size = 1
  }

  expect_failures = [var.node_desired_size]
}

run "pod_identity_usa_o_principal_certo" {
  command = plan

  assert {
    condition = alltrue([
      for r in [aws_iam_role.lbc, aws_iam_role.eso] :
      jsondecode(r.assume_role_policy).Statement[0].Principal.Service == "pods.eks.amazonaws.com"
      && contains(jsondecode(r.assume_role_policy).Statement[0].Action, "sts:TagSession")
    ])
    error_message = "As roles de Pod Identity devem confiar em pods.eks.amazonaws.com com sts:AssumeRole e sts:TagSession."
  }
}

run "eso_so_le_segredos_do_prefixo" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role_policy.eso.policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:eks-lab/*"
    error_message = "A policy do ESO deve se limitar aos segredos do prefixo eks-lab/."
  }

  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.eso.policy).Statement[0].Action, "*") && !contains(jsondecode(aws_iam_role_policy.eso.policy).Statement[0].Action, "secretsmanager:*")
    error_message = "A policy do ESO não pode ter ação com curinga."
  }
}

run "associacoes_apontam_para_a_conta_de_servico_certa" {
  command = plan

  assert {
    condition     = aws_eks_pod_identity_association.lbc.namespace == "kube-system" && aws_eks_pod_identity_association.lbc.service_account == "aws-load-balancer-controller"
    error_message = "O LBC deve ser associado a kube-system/aws-load-balancer-controller."
  }

  assert {
    condition     = aws_eks_pod_identity_association.eso.namespace == "external-secrets" && aws_eks_pod_identity_association.eso.service_account == "external-secrets"
    error_message = "O ESO deve ser associado a external-secrets/external-secrets."
  }
}

run "prefixo_de_segredos_com_curinga_e_recusado" {
  command = plan

  variables {
    secrets_prefix = "*"
  }

  expect_failures = [var.secrets_prefix]
}
