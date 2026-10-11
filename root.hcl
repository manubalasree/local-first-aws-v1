# Root config. Every environment inherits this via `include "root"`.
# The ONLY place that knows how Floci and real AWS differ.

locals {
  # Read the nearest env.hcl above the child module (live/<env>/env.hcl).
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  environment = local.env.environment
  use_floci   = local.env.use_floci
  region      = local.env.aws_region
  account_id  = local.env.account_id
  endpoint    = local.env.endpoint

  project    = "floci-to-cloud"
  state_bucket = "${local.project}-tfstate-${local.account_id}"
  lock_table   = "${local.project}-tflock"

  # --- provider: local (Floci) -------------------------------------------
  # Endpoint overrides exist ONLY here. Credentials come from the shell
  # (AWS_ACCESS_KEY_ID=test / AWS_SECRET_ACCESS_KEY=test), never from the repo.
  provider_local = <<-EOF
    provider "aws" {
      region = "${local.region}"

      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      s3_use_path_style           = true

      endpoints {
        s3         = "${local.endpoint}"
        cloudfront = "${local.endpoint}"
        dynamodb   = "${local.endpoint}"
        iam        = "${local.endpoint}"
        sts        = "${local.endpoint}"
      }

      default_tags {
        tags = {
          project     = "${local.project}"
          environment = "${local.environment}"
        }
      }
    }
  EOF

  # --- provider: prod (real AWS) -----------------------------------------
  # No endpoints, no skip_* flags. allowed_account_ids makes Terraform refuse
  # to run if your credentials point at any other account (e.g. Floci's 000000000000).
  provider_prod = <<-EOF
    provider "aws" {
      region              = "${local.region}"
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = {
          project     = "${local.project}"
          environment = "${local.environment}"
        }
      }
    }
  EOF

  # Backend settings shared by both environments.
  backend_common = {
    bucket         = local.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = local.lock_table

    # Bucket and table were bootstrapped by hand (see runbook).
    # Stop Terragrunt from creating or modifying them.
    disable_bucket_update = true
  }

  # Extra settings only the local backend needs.
  backend_local = {
    endpoints = {
      s3       = local.endpoint
      dynamodb = local.endpoint
      sts      = local.endpoint
      iam      = local.endpoint
    }
    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = merge(
    local.backend_common,
    # A ternary would fail (object vs {} have inconsistent types); a filtered
    # for-expression yields {} when use_floci is false.
    { for k, v in local.backend_local : k => v if local.use_floci }
  )
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.use_floci ? local.provider_local : local.provider_prod
}
