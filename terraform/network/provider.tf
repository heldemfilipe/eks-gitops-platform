# Modo estudo: credenciais falsas, nenhum comando fala com a AWS e nada é criado.
provider "aws" {
  region                      = var.region
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true

  default_tags {
    tags = var.tags
  }
}
