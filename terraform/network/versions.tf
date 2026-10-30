terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Estudo, nunca aplicado na AWS: o state seria local e fica fora do git. Em uso real,
  # entraria aqui o backend S3 com use_lockfile = true, como no terraform-aws-foundation.
}
