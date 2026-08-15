terraform {
  required_version = ">= 1.7.0" # 1.7+ needed for mock_provider in tests/

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
