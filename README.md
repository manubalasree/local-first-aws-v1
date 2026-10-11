# local-first-aws-v1

A local-first AWS workflow: run [Floci](https://floci.io) (a free local AWS emulator) in rootless Podman, apply one Terragrunt/Terraform module to it in seconds, then apply the **same code** to real AWS, changing only environment config.

The module is a demonstrator: a private S3 bucket behind CloudFront with an origin access control (OAC) and a one-page static site. The pattern is the part to reuse.

## Layout

```
root.hcl                          # generates provider + backend per environment
live/
  local/env.hcl                   # Floci settings (use_floci = true)
  local/static-site/terragrunt.hcl
  prod/env.hcl                    # real AWS settings (use_floci = false)
  prod/static-site/terragrunt.hcl
modules/static-site/              # S3 + OAC + bucket policy + CloudFront + index.html
podman/floci.container            # rootless Podman Quadlet for Floci
site/index.html
GAPS.md                           # observed Floci vs real AWS differences
```

The module knows nothing about Floci or AWS. Endpoint overrides exist only in the local branch of `root.hcl`.

## Tested with

Floci `2.2.0`, Terraform `1.16.5`, Terragrunt `1.1.6`, Ubuntu 26.04 (VM with rootless Podman). One run on that setup; nothing else has been tried.

## Quick start (local, Floci)

1. Install the Quadlet and start Floci. Change the IP in `FLOCI_HOSTNAME` and `FLOCI_BASE_URL` to your host's address.
   ```bash
   cp podman/floci.container ~/.config/containers/systemd/
   systemctl --user daemon-reload && systemctl --user start floci
   ```
   This needs a real login session (`systemctl --user` must work) and `podman.socket` enabled (`systemctl --user enable --now podman.socket`).
2. Point your shell at Floci and check which cloud you are talking to:
   ```bash
   export FLOCI_ENDPOINT=http://<floci-host>:4566
   export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
   export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=ca-central-1
   aws sts get-caller-identity   # Account must be 000000000000
   ```
3. Create the state backend by hand, once (Terraform cannot create the backend it uses):
   ```bash
   B=floci-to-cloud-tfstate-000000000000
   aws s3api create-bucket --bucket $B --create-bucket-configuration LocationConstraint=ca-central-1
   aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled
   aws dynamodb create-table --table-name floci-to-cloud-tflock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST
   ```
4. Apply and look at the page. The distribution's hostname has no DNS, so send it as a `Host` header:
   ```bash
   cd live/local/static-site
   terragrunt apply
   curl -H "Host: $(terragrunt output -raw distribution_domain_name)" http://<floci-host>:4566/
   ```

## Promote to real AWS

Use a **new shell**, so no Floci variable can leak in.

```bash
unset FLOCI_ENDPOINT AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws sso login --profile <profile>
export AWS_PROFILE=<profile>
export AWS_ACCOUNT_ID=<your-12-digit-account-id>
aws sts get-caller-identity   # must be YOUR account, not 000000000000
```

Create the same state bucket (`floci-to-cloud-tfstate-<account-id>`) and lock table in the region named in `live/prod/env.hcl`, then:

```bash
cd live/prod/static-site
terragrunt plan     # read it first
terragrunt apply    # CloudFront takes several minutes to deploy
```

## Safety

- Floci has **no authentication**. Allow its port from your LAN only; never expose it further.
- `get_env("AWS_ACCOUNT_ID")` and `get_env("FLOCI_ENDPOINT")` have no defaults, so an unset variable stops the run.
- The prod provider sets `allowed_account_ids`, so Terraform refuses any other account, including Floci's `000000000000`.
- `force_destroy = true` is set for easy teardown on a throwaway run. Do not keep it in a real production setup.
- Set a budget alarm (AWS Budgets) before the first prod apply.
- Never commit state files or `.terragrunt-cache`.

## Teardown

`terragrunt destroy` in each `live/*/static-site` first, then delete the state bucket and lock table by hand, last. The bucket is versioned, so empty all versions before deleting it, and check the bucket name before every delete.

## Where Floci and AWS differ

See [GAPS.md](GAPS.md) for what was observed: no CloudFront response headers or HTTP-to-HTTPS redirect on Floci, opt-in bucket-policy enforcement, and a first plan that is not clean after a create.
