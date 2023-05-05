terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.65"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.3.0"
    }
  }
}
