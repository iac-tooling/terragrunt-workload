/*==== 
Security Group (SG) Terragrunt Configuration EKS
=====*/

terraform {
  source = "tfr://terraform-aws-modules/security-group/aws?version=5.2.0"
}

include {
  path = find_in_parent_folders("common/common.hcl")
}

dependencies {
  paths = ["../../vpc/eks-vpc"]
}

dependency "eks_vpc" {
  config_path = "../../vpc/eks-vpc"
  mock_outputs = {
    vpc_id         = "vpc-123456789"
    private_subnets = ["subnet-123456789", "subnet-123456789", "subnet-123456789"]
    public_subnets  = ["subnet-123456789", "subnet-123456789", "subnet-123456789"]
  # skip_outputs = false
  mock_outputs_merge_strategy_with_state = "shallow"
  }
}

locals {
  # Load environment-specific configurations from env.yaml
  env_vars = yamldecode(file(find_in_parent_folders("common/env.yaml")))
  
  # Define the region key and VPC name
  region_key = "id"  # Indonesia region

  # Set AWS region and assume role ARN based on the environment
  aws_region      = local.env_vars["environments"][local.region_key]["aws_region"]
  assume_role_arn = local.env_vars["environments"][local.region_key]["assume_role_arn"]

  sg_name        = "eks-security-group"
  sg_description = "Security group for EKS nodes"

  # Tags for resources
  default_tags = {
    Environment = "nonprod"
    Team        = "infrastructure"
  }

  # Trusted CIDR blocks for ingress
  trusted_cidr_blocks = "10.4.1.0/24, 10.4.2.0/24, 10.4.3.0/24, 10.4.4.0/24"
}

inputs = {
  name        = local.sg_name
  description = local.sg_description

  # ID of the VPC where to create security group
  # type: string
  vpc_id          = dependency.eks_vpc.outputs.vpc_id

  private_subnets = dependency.eks_vpc.outputs.private_subnets
  public_subnets  = dependency.eks_vpc.outputs.public_subnets  
  tags            = local.default_tags

  # List of IPv4 CIDR ranges to use on all egress rules
  # type: list(string)
  # Secure ingress rules
  ingress_cidr_blocks = ["0.0.0.0/0"]

  # List of ingress rules to create by name
  # type: list(string)
  ingress_rules = ["https-443-tcp"]

  # Egress Rules
  egress_with_cidr_blocks = [
    {
      rule        = "all-tcp"
      cidr_blocks = "0.0.0.0/0"  # Allow outbound to the internet
    }
  ]
}
