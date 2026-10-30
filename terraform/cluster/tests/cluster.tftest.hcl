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
