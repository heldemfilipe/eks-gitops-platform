terraform {
  required_version = ">= 1.10"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # State local, fora do git. Esta é a única camada aplicada de verdade, e só no kind.
}
