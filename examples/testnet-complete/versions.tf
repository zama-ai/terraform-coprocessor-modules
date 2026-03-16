terraform {
  required_version = ">= 1.11"

  # Remote state — replace with your own bucket before applying.
  backend "s3" {
    bucket       = "your-terraform-state-bucket" # CHANGE ME
    key          = "coprocessor/testnet/terraform.tfstate"
    region       = "eu-west-1" # CHANGE ME: match aws_region
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
