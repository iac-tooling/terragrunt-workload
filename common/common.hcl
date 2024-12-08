/*==== 
Common Terragrunt Configuration 
=====*/

locals {
  backend_bucket_name   = "workload-state"
  backend_key           = "${path_relative_to_include()}.tfstate"
  backend_region        = "region"
  backend_encrypt       = true
  backend_dynamodb_lock = "workload-tfstate-locking"

  # Define shared assume role
  assume_role_arn = "arn:aws:iam::123456789:role/workload-role"
}

# Inputs consolidating the values from locals
inputs = {
  aws_region      = local.backend_region
  assume_role_arn = local.assume_role_arn
}

# Generate Terraform version requirements
generate "versions" {
  path      = "versions.tf"
  if_exists = "skip"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "skip"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.assume_role_arn
  }

  skip_credentials_validation = true
  skip_region_validation      = true
}

variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
}

variable "assume_role_arn" {
  description = "IAM role ARN to assume"
  type        = string
}
EOF
}
