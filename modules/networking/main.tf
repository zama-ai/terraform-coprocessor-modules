data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = length(var.vpc.availability_zones) > 0 ? var.vpc.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    min(3, length(data.aws_availability_zones.available.names))
  )

  vpc_cidr_prefix = parseint(split("/", var.vpc.cidr)[1], 10)

  private_newbits    = var.vpc.use_subnet_calc_v2 ? var.vpc.private_subnet_cidr_mask - local.vpc_cidr_prefix : 8
  public_newbits     = var.vpc.use_subnet_calc_v2 ? var.vpc.public_subnet_cidr_mask - local.vpc_cidr_prefix : 8
  additional_newbits = var.additional_subnets.enabled ? var.additional_subnets.cidr_mask - local.vpc_cidr_prefix : 4

  public_start_index = var.vpc.use_subnet_calc_v2 ? (
    length(local.availability_zones) * pow(2, local.public_newbits - local.private_newbits)
  ) : length(local.availability_zones)

  additional_start_index = var.additional_subnets.enabled ? ceil(
    (local.public_start_index + length(local.availability_zones)) /
    pow(2, local.public_newbits - local.additional_newbits)
  ) : 0

  private_subnets = [
    for k, v in local.availability_zones :
    cidrsubnet(var.vpc.cidr, local.private_newbits, k)
  ]

  public_subnets = [
    for k, v in local.availability_zones :
    cidrsubnet(var.vpc.cidr, local.public_newbits, local.public_start_index + k)
  ]

  additional_subnet_cidrs = var.additional_subnets.enabled ? [
    for k, v in local.availability_zones :
    cidrsubnet(var.vpc.cidr, local.additional_newbits, local.additional_start_index + k)
  ] : []

  # Subnet tags for additional subnets
  additional_eks_tags = var.additional_subnets.expose_for_eks ? {
    "karpenter.sh/discovery"                        = var.eks_cluster_name
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
    "kubernetes.io/role/cni"                        = "1"
  } : {}

  additional_elb_tags = !var.additional_subnets.expose_for_eks ? {} : (
    var.additional_subnets.elb_role == "internal" ? { "kubernetes.io/role/internal-elb" = "1" } :
    var.additional_subnets.elb_role == "public" ? { "kubernetes.io/role/elb" = "1" } :
    {}
  )
}

# ***************************************
#  VPC
# ***************************************
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.partner_name}-${var.environment}"
  cidr = var.vpc.cidr

  azs             = local.availability_zones
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.vpc.single_nat_gateway
  one_nat_gateway_per_az = !var.vpc.single_nat_gateway
  create_egress_only_igw = true

  enable_flow_log           = var.vpc.flow_log_enabled
  flow_log_destination_type = var.vpc.flow_log_enabled ? "s3" : null
  flow_log_destination_arn  = var.vpc.flow_log_enabled ? var.vpc.flow_log_destination_arn : null

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = merge(
    { "kubernetes.io/role/internal-elb" = 1 },
    var.enable_karpenter ? { "karpenter.sh/discovery" = var.eks_cluster_name } : {}
  )
}

# ***************************************
#  Additional Subnets
# ***************************************
resource "aws_subnet" "additional" {
  count = var.additional_subnets.enabled ? length(local.availability_zones) : 0

  vpc_id            = module.vpc.vpc_id
  availability_zone = local.availability_zones[count.index]
  cidr_block        = local.additional_subnet_cidrs[count.index]

  tags = merge(
    { Name = "${var.partner_name}-${var.environment}-additional-${local.availability_zones[count.index]}" },
    var.additional_subnets.tags,
    local.additional_eks_tags,
    local.additional_elb_tags
  )
}

resource "aws_route_table_association" "additional" {
  count          = var.additional_subnets.enabled ? length(aws_subnet.additional) : 0
  subnet_id      = aws_subnet.additional[count.index].id
  route_table_id = module.vpc.private_route_table_ids[count.index]
}