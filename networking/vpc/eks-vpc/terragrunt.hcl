/*==== 
Virtual Private Cloud (VPC) Terragrunt Configuration 
=====*/

terraform {
  source = "tfr://terraform-aws-modules/vpc/aws?version=5.16.0"
}

include {
  path = find_in_parent_folders("common/common.hcl")
}

locals {
  # Load environment-specific configurations from env.yaml
  env_vars = yamldecode(file(find_in_parent_folders("common/env.yaml")))
  
  # Define the region key and VPC name
  region_key = "id"  # Indonesia region
  vpc_name   = "eks-vpc"  # Name for the VPC

  # Set AWS region and assume role ARN based on the environment
  aws_region      = local.env_vars["environments"][local.region_key]["aws_region"]
  assume_role_arn = local.env_vars["environments"][local.region_key]["assume_role_arn"]

  # Availability Zones
  azs = ["ap-southeast-3a", "ap-southeast-3b", "ap-southeast-3c"]

  # Subnets
  subnets = {
    public = [
      { cidr_block = "10.4.1.0/24", az = local.azs[0] },
      { cidr_block = "10.4.2.0/24", az = local.azs[1] },
      { cidr_block = "10.4.3.0/24", az = local.azs[2] }
    ],
    private = [
      { cidr_block = "10.4.4.0/24", az = local.azs[0] },
      { cidr_block = "10.4.5.0/24", az = local.azs[1] },
      { cidr_block = "10.4.6.0/24", az = local.azs[2] }
    ]
  }

  # Tags for resources
  default_tags = {
    Environment = "nonprod"
    Team        = "infrastructure"
  }

  # Single NAT Gateway Setting
  use_single_nat_gateway = true

  # NAT Gateway Tags
  nat_gateway_tags = local.use_single_nat_gateway ? {
    "nat-single" = jsonencode(merge(local.default_tags, { Name = "${local.vpc_name}-nat-single" }))
  } : {
    "nat-ap-southeast-3a" = jsonencode(merge(local.default_tags, { Name = "${local.vpc_name}-nat-ap-southeast-3a" })),
    "nat-ap-southeast-3b" = jsonencode(merge(local.default_tags, { Name = "${local.vpc_name}-nat-ap-southeast-3b" })),
    "nat-ap-southeast-3c" = jsonencode(merge(local.default_tags, { Name = "${local.vpc_name}-nat-ap-southeast-3c" }))
  }

  # Route Table Names
  route_table_names = {
    public  = "${local.vpc_name}-rt-public"
    private = [for az in local.azs : "${local.vpc_name}-rt-private-${az}"]
  }
}

inputs = {
  # General VPC settings
  name             = local.vpc_name
  aws_region       = local.aws_region
  assume_role_arn  = local.assume_role_arn
  cidr             = "10.4.0.0/16"

  # Subnet configurations
  public_subnets   = [for subnet in local.subnets.public : subnet.cidr_block]
  private_subnets  = [for subnet in local.subnets.private : subnet.cidr_block]
  azs              = local.azs

  # NAT Gateway tags
  nat_gateway_tags = local.nat_gateway_tags  # Pass the map of strings here

  # Route tables
  route_tables = {
    public = {
      name    = local.route_table_names.public
      routes  = [
        { destination_cidr_block = "0.0.0.0/0", gateway_id = "igw" }
      ]
    }
    private = {
      per_az = true  # One route table per AZ
      names  = local.route_table_names.private
      routes = [
        { destination_cidr_block = "0.0.0.0/0", nat_gateway_id = "nat" }
      ]
    }
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # Main route table
  main_route_table_id = local.route_table_names.public  # Explicitly set public route table as main
  assign_generated_route_table_to_main_route_table = false  # Disable AWS default route table behavior

  # Internet Gateway
  create_internet_gateway = true
  internet_gateway_name   = "${local.vpc_name}-igw"

  # NAT Gateway settings
  enable_nat_gateway = true
  single_nat_gateway = local.use_single_nat_gateway

  # DNS settings
  enable_dns_support      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true

  # Flow log settings
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_destination_type            = "cloud-watch-logs"
  flow_log_log_group_retention_in_days = 90

  # Tags for all resources
  tags = local.default_tags
}
