locals {
  k8s_host     = coalesce(var.kubernetes.host, one(module.eks[*].cluster_endpoint))
  k8s_ca_cert  = coalesce(var.kubernetes.cluster_ca_certificate, one(module.eks[*].cluster_certificate_authority_data))
  k8s_cluster  = coalesce(var.kubernetes.cluster_name, one(module.eks[*].cluster_name))
}

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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
  host                   = local.k8s_host != null ? local.k8s_host : ""
  cluster_ca_certificate = local.k8s_ca_cert != null ? base64decode(local.k8s_ca_cert) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.k8s_cluster != null ? local.k8s_cluster : ""]
  }
}