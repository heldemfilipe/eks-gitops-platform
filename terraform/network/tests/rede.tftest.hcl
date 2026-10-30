mock_provider "aws" {}

run "plan_com_os_padroes" {
  command = plan

  assert {
    condition     = length(output.private_subnet_ids) == 2 && length(output.public_subnet_ids) == 2
    error_message = "Devem existir duas sub-redes públicas e duas privadas."
  }
}

run "uma_zona_so_e_rejeitada" {
  command = plan

  variables {
    azs = ["us-east-1a"]
  }

  expect_failures = [var.azs]
}
