# Environment settings: prod (real AWS)
locals {
  environment = "prod"
  use_floci   = false
  aws_region  = "ca-central-1"
  account_id  = get_env("AWS_ACCOUNT_ID") # no default: errors if unset (CI: vars.AWS_ACCOUNT_ID)
  endpoint    = "" # unused in prod; must stay empty
}
