# local-first-aws-v1

Companion code for the article **[34 Seconds on Floci, 7 Minutes on AWS: Same Terraform, Two Clouds](ARTICLE-URL-TBD)**.

It runs [Floci](https://floci.io), a free local AWS emulator, in rootless Podman, applies one Terragrunt/Terraform module (a private S3 bucket behind CloudFront with an origin access control) to it in seconds, then applies the same code to real AWS, changing only environment config.

**Start with the article.** It explains the setup, the commands and the gotchas; this repo holds the files it refers to.

- Floci setup: `podman/floci.container`
- Terragrunt config: `root.hcl`, `live/`
- Module: `modules/static-site/`
- Observed Floci vs AWS differences: [GAPS.md](GAPS.md)

Tested with Floci `2.2.0`, Terraform `1.16.5` and Terragrunt `1.1.6`, on one setup. Floci has no authentication, so keep it off any network you don't trust.
