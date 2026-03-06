terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}

provider "kubernetes" {
  host                   = one(module.eks[*].cluster_endpoint) != null ? one(module.eks[*].cluster_endpoint) : ""
  cluster_ca_certificate = one(module.eks[*].cluster_certificate_authority_data) != null ? base64decode(one(module.eks[*].cluster_certificate_authority_data)) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", one(module.eks[*].cluster_name) != null ? one(module.eks[*].cluster_name) : ""]
  }
}