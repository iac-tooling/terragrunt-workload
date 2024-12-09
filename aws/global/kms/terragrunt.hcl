/*==== 
Key Management Service (KMS) Terragrunt Configuration 
=====*/

terraform {
  source = "tfr://terraform-aws-modules/kms/aws//wrappers?version=3.1.0"
}

# Include shared configuration
include {
  path = find_in_parent_folders("common/common.hcl")
}

locals {
  # Load environment variables from YAML
  env_vars = yamldecode(file(find_in_parent_folders("common/env.yaml")))

  # Define region_key directly
  region_key = "id"  # Replace with the desired region key (e.g., "id" for Indonesia)

  # Dynamically fetch AWS region and assume role ARN from env.yaml
  aws_region      = local.env_vars["environments"][local.region_key]["aws_region"]
  assume_role_arn = local.env_vars["environments"][local.region_key]["assume_role_arn"]

  # Load KMS keys from the global YAML file
  keys_data = yamldecode(file("${get_terragrunt_dir()}/kms_keys.yaml")).keys

  # Default configuration values for KMS keys
  defaults = {
    enable_key_rotation        = true
    deletion_window_in_days    = 30
    key_usage                  = "ENCRYPT_DECRYPT"
    customer_master_key_spec   = "SYMMETRIC_DEFAULT"
    multi_region               = true  # Enable multi-region replication
    tags                       = { Environment = "nonprod", Team = "infrastructure" }  # Default tags
  }
}

inputs = {
  # Pass AWS region and assume role to the module
  aws_region      = local.aws_region
  assume_role_arn = local.assume_role_arn

  # Define KMS key configurations dynamically
  items = {
    for key in local.keys_data : key.aliases[0] => merge(
      local.defaults,
      {
        aliases     = key.aliases,
        description = key.description,
        policy      = file("${find_in_parent_folders("aws/global/policies")}/${key.policy_file}"),
        tags        = merge(local.defaults.tags, key.tags)
      }
    )
  }
}
