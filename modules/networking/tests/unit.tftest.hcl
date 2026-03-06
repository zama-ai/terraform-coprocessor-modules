mock_provider "aws" {}

# Shared defaults across all runs.
# Explicit availability_zones bypass data.aws_availability_zones so the mock
# provider's empty-list response never comes into play for most tests.
variables {
  partner_name     = "acme"
  environment      = "mainnet"
  eks_cluster_name = "acme-mainnet"
  enable_karpenter = false

  vpc = {
    cidr                     = "10.0.0.0/16"
    availability_zones       = ["eu-west-1a", "eu-west-1b"]
    use_subnet_calc_v2       = true
    private_subnet_cidr_mask = 24
    public_subnet_cidr_mask  = 24
  }

  additional_subnets = { enabled = false }
}

# =============================================================================
#  Additional subnets — enabled / disabled
# =============================================================================

run "no_additional_subnets_by_default" {
  command = plan

  assert {
    condition     = length(aws_subnet.additional) == 0
    error_message = "No additional subnets must be created when additional_subnets.enabled = false."
  }

  assert {
    condition     = length(aws_route_table_association.additional) == 0
    error_message = "No route table associations must be created when additional_subnets.enabled = false."
  }
}

run "additional_subnets_one_per_az" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  assert {
    condition     = length(aws_subnet.additional) == 2
    error_message = "One additional subnet must be created per AZ."
  }

  assert {
    condition     = length(aws_route_table_association.additional) == 2
    error_message = "One route table association must be created per additional subnet."
  }
}

# =============================================================================
#  CIDR calculation
#
# Shared inputs: cidr = "10.0.0.0/16", private_mask = 24, public_mask = 24,
#                azs = ["eu-west-1a", "eu-west-1b"]
#
# private_newbits         = 24 - 16 = 8
# public_newbits          = 24 - 16 = 8
# public_start_index      = 2 * pow(2, 8-8) = 2
# additional_newbits      = 20 - 16 = 4    (cidr_mask = 20)
# additional_start_index  = ceil((2+2) / pow(2, 8-4)) = ceil(4/16) = 1
#
# additional[0]: cidrsubnet("10.0.0.0/16", 4, 1) = "10.0.16.0/20"
# additional[1]: cidrsubnet("10.0.0.0/16", 4, 2) = "10.0.32.0/20"
# =============================================================================

run "additional_subnet_cidrs_calculated_correctly" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  assert {
    condition     = aws_subnet.additional[0].cidr_block == "10.0.16.0/20"
    error_message = "First additional subnet CIDR must be 10.0.16.0/20."
  }

  assert {
    condition     = aws_subnet.additional[1].cidr_block == "10.0.32.0/20"
    error_message = "Second additional subnet CIDR must be 10.0.32.0/20."
  }
}

run "additional_subnet_az_assignments_match_input" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  assert {
    condition     = aws_subnet.additional[0].availability_zone == "eu-west-1a"
    error_message = "First additional subnet must be placed in the first AZ."
  }

  assert {
    condition     = aws_subnet.additional[1].availability_zone == "eu-west-1b"
    error_message = "Second additional subnet must be placed in the second AZ."
  }
}

# =============================================================================
#  Additional subnet name tags
# =============================================================================

run "additional_subnet_name_tag_includes_az" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  assert {
    condition     = aws_subnet.additional[0].tags["Name"] == "acme-mainnet-additional-eu-west-1a"
    error_message = "Additional subnet Name tag must include partner_name, environment, and AZ."
  }
}

# =============================================================================
#  EKS / Karpenter subnet tags
# =============================================================================

run "no_eks_tags_when_expose_for_eks_false" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "karpenter.sh/discovery")
    error_message = "karpenter.sh/discovery tag must not be set when expose_for_eks = false."
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "kubernetes.io/role/cni")
    error_message = "kubernetes.io/role/cni tag must not be set when expose_for_eks = false."
  }
}

run "eks_tags_applied_when_expose_for_eks_true" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = true
    }
  }

  assert {
    condition     = aws_subnet.additional[0].tags["karpenter.sh/discovery"] == "acme-mainnet"
    error_message = "karpenter.sh/discovery tag must equal the EKS cluster name when expose_for_eks = true."
  }

  assert {
    condition     = aws_subnet.additional[0].tags["kubernetes.io/role/cni"] == "1"
    error_message = "kubernetes.io/role/cni tag must be set when expose_for_eks = true."
  }
}

# =============================================================================
#  ELB role tags (only applied when expose_for_eks = true)
# =============================================================================

run "internal_elb_tag_when_elb_role_internal" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = true
      elb_role       = "internal"
    }
  }

  assert {
    condition     = aws_subnet.additional[0].tags["kubernetes.io/role/internal-elb"] == "1"
    error_message = "kubernetes.io/role/internal-elb tag must be set when elb_role = 'internal'."
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "kubernetes.io/role/elb")
    error_message = "kubernetes.io/role/elb tag must not be set when elb_role = 'internal'."
  }
}

run "public_elb_tag_when_elb_role_public" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = true
      elb_role       = "public"
    }
  }

  assert {
    condition     = aws_subnet.additional[0].tags["kubernetes.io/role/elb"] == "1"
    error_message = "kubernetes.io/role/elb tag must be set when elb_role = 'public'."
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "kubernetes.io/role/internal-elb")
    error_message = "kubernetes.io/role/internal-elb tag must not be set when elb_role = 'public'."
  }
}

run "no_elb_tag_when_elb_role_null" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = true
      elb_role       = null
    }
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "kubernetes.io/role/elb")
    error_message = "kubernetes.io/role/elb tag must not be set when elb_role = null."
  }

  assert {
    condition     = !contains(keys(aws_subnet.additional[0].tags), "kubernetes.io/role/internal-elb")
    error_message = "kubernetes.io/role/internal-elb tag must not be set when elb_role = null."
  }
}

# =============================================================================
#  User-supplied extra tags on additional subnets
# =============================================================================

run "user_tags_merged_onto_additional_subnets" {
  command = plan

  variables {
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
      tags           = { Purpose = "cni-additional", Team = "platform" }
    }
  }

  assert {
    condition     = aws_subnet.additional[0].tags["Purpose"] == "cni-additional"
    error_message = "User-supplied Purpose tag must be present on additional subnets."
  }

  assert {
    condition     = aws_subnet.additional[0].tags["Team"] == "platform"
    error_message = "User-supplied Team tag must be present on additional subnets."
  }
}

# =============================================================================
#  AZ auto-detection via data source
#
# When availability_zones = [], the module slices data.aws_availability_zones.
# Use override_data to simulate 3 AZs being returned.
# =============================================================================

run "az_auto_detected_from_data_source" {
  command = plan

  variables {
    vpc = {
      cidr                     = "10.0.0.0/16"
      availability_zones       = []
      use_subnet_calc_v2       = true
      private_subnet_cidr_mask = 24
      public_subnet_cidr_mask  = 24
    }
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"] }
  }

  assert {
    condition     = length(aws_subnet.additional) == 3
    error_message = "Three additional subnets must be created when data source returns 3 AZs."
  }
}

run "az_auto_detection_capped_at_three" {
  command = plan

  variables {
    vpc = {
      cidr                     = "10.0.0.0/16"
      availability_zones       = []
      use_subnet_calc_v2       = true
      private_subnet_cidr_mask = 24
      public_subnet_cidr_mask  = 24
    }
    additional_subnets = {
      enabled        = true
      cidr_mask      = 20
      expose_for_eks = false
    }
  }

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["eu-west-1a", "eu-west-1b", "eu-west-1c", "eu-west-1d"] }
  }

  assert {
    condition     = length(aws_subnet.additional) == 3
    error_message = "AZ auto-detection must be capped at 3 even when more AZs are available."
  }
}
