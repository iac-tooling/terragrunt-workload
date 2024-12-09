/*==== 
Elastic Kubernetes Service (EKS) Terragrunt Configuration 
=====*/

terraform {
  source = "tfr://terraform-aws-modules/eks/aws?version=20.31.1"
}

# Include shared configuration
include {
  path = find_in_parent_folders("common/common.hcl")
}

# Dependency block for VPC
dependency "eks_vpc" {
  config_path = "../../networking/vpc/eks-vpc"
  mock_outputs = {
    vpc_id         = "vpc-123456789"
    private_subnets = ["subnet-123456789", "subnet-123456789", "subnet-123456789"]
    public_subnets  = ["subnet-123456789", "subnet-123456789", "subnet-123456789"]
  }
  mock_outputs_merge_strategy_with_state = "shallow"
}

# Dependency block for Security Group
dependency "eks-sg" {
  config_path = "../../networking/security-group/eks-sg"
  mock_outputs = {
    security_group_id = "sg-123456789"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
}

# Dependency block for Security Group
dependency "eks_sg" {
  config_path = "../../networking/security-group/eks-sg"
  mock_outputs = {
    security_group_id = "sg-123456789"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
}

dependency "kms" {
  config_path = "../../global/kms"
  mock_outputs = {
    key_id = "123456789"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
}


locals {
  # Load environment and region-specific configurations
  env_vars   = yamldecode(file(find_in_parent_folders("common/env.yaml")))

  # Define the region key and EKS cluster name
  region_key     = "id"  # Indonesia region
  cluster_name   = "nonprod-cluster"  # Name for the EKS cluster
  cluster_version = "1.31"  # EKS cluster version

  # Dynamically fetch AWS region and assume role ARN from env.yaml
  aws_region      = local.env_vars["environments"][local.region_key]["aws_region"]
  assume_role_arn = local.env_vars["environments"][local.region_key]["assume_role_arn"]

}


inputs = {
  aws_region      = local.aws_region
  assume_role_arn = local.assume_role_arn
  # Use dynamic values and defaults for the cluster
  cluster_name           = local.cluster_name
  cluster_version        = local.cluster_version

  # Fetch VPC outputs dynamically from dependency
  vpc_id                 = dependency.eks_vpc.outputs.vpc_id
  subnet_ids             = dependency.eks_vpc.outputs.private_subnets
  security_group_ids     = dependency.eks_sg.outputs.security_group_id

  # Fetch KMS key ID dynamically from dependency
  kms_key_id             = dependency.kms.outputs.key_id

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }
}
