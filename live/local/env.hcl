# Environment settings: local (Floci on podman-vm)
locals {
  environment = "local"
  use_floci   = true
  aws_region  = "ca-central-1"
  account_id  = "000000000000" # Floci's fixed account ID
  endpoint    = get_env("FLOCI_ENDPOINT") # no default: errors if unset (set by the workflow job, vars.FLOCI_ENDPOINT)
}
