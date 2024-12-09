/*==== 
Global Terragrunt Configuration 
=====*/

locals {
  # Reference shared configuration values from common.hcl
  common_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/common/common.hcl")

  # Load environment-specific variables
  environment_file = "${get_parent_terragrunt_dir()}/common/env.yaml"
  environment      = yamldecode(file(local.environment_file))

  # Derive the region key dynamically based on the directory structure
  region_key = basename(get_terragrunt_dir())

  rassume_role_arn_key = basename(get_terragrunt_dir())

  # Fetch region-specific configuration
  region_config = lookup(local.environment["environments"], local.region_key, {})

  # Assume role configuration
  assume_role_arn = lookup(local.environment["environments"], local.assume_role_arn, {})

  assume_role_arn = lookup(local.region_config, "assume_role_arn", null)
}

# Define remote state configuration
remote_state {
  backend = "s3"
  config = {
    bucket         = local.common_vars.locals.backend_bucket_name
    key            = "${path_relative_to_include()}.tfstate"
    region         = local.common_vars.locals.backend_region
    encrypt        = local.common_vars.locals.backend_encrypt
    dynamodb_table = local.common_vars.locals.backend_dynamodb_lock
  }
}

terraform {
  # Exclude conflicting versions.tf file in the Terraform module
  extra_arguments "remove_versions" {
    commands = ["init", "validate", "plan", "apply"]
    arguments = ["-exclude-config=versions.tf"]
  }

  # Backend initialization arguments
  extra_arguments "init_backend" {
    commands = ["init"]
    arguments = ["-reconfigure"]
  }

  # Load common variables
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    arguments = [
      "-var-file=${find_in_parent_folders("common.tfvars")}"
    ]
  }

  # Disable interactive input for automation
  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }
}
