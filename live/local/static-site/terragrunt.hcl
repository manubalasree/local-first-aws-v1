locals {
  env      = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  repo_dir = dirname(find_in_parent_folders("root.hcl"))
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/static-site"
}

# Only values that differ per environment. Module inputs are placeholders
# until modules/static-site exists.
inputs = {
  environment     = local.env.environment
  bucket_name     = "floci-to-cloud-${local.env.environment}-site-${local.env.account_id}"
  index_html_path = "${local.repo_dir}/site/index.html"
  force_destroy   = true # teardown convenience
}
