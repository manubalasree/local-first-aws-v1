# Floci vs real AWS: observed gaps

Same Terragrunt code and `static-site` module, applied to Floci (`floci/floci:2.2.0`, rootless Podman on an Incus VM) and to real AWS. Every row was observed on 10 to 11 Oct 2026, unless marked **not tested on AWS**.

| # | Area | Floci | Real AWS | Matters because |
|---|---|---|---|---|
| 1 | Apply time (whole `terragrunt apply`) | ~34 s clean (`-auto-approve`, providers cached); ~42 s on the first run | ~7 min 04 s, almost all waiting for CloudFront `Deployed` | The thesis: fast, free feedback. About 12x. |
| 2 | CloudFront response headers | S3 headers only | `x-cache`, `via`, `x-amz-cf-pop`, `x-amz-cf-id` | Floci proxies S3; it does not emulate the edge. Cache behaviour can't be tested locally. |
| 3 | `redirect-to-https` | HTTP returns 200, no redirect | HTTP returns 301 | A viewer-protocol-policy mistake would not show up locally. |
| 4 | Anonymous direct S3 GET | 200 by default; **403 only with `FLOCI_SERVICES_S3_ENFORCE_AUTH=true`** | 403 | Without the flag, a broken OAC / bucket policy passes locally. |
| 5 | Anonymous `ListBuckets` | **200, lists bucket names, even with enforcement on** | **307 redirect to `https://aws.amazon.com/s3/` with an empty body** (verified with `--debug`; a followed `curl -L` returned 200 for that marketing page, and the CLI failed to parse the empty body). No bucket names are returned. | The LAN firewall is the real barrier on Floci, not the flag. |
| 6 | Unknown `Host` header | Falls through to the S3 endpoint (returned `ListAllMyBucketsResult`) | **403** (verified: `Host: bogus.cloudfront.net` sent to the distribution's address) | Hostname behaviour can't be validated locally. |
| 7 | First plan after create | 2 changes: distribution `tags_all` plus a knock-on bucket-policy diff. One more apply, then `No changes` | `No changes` on the first plan | A "plan must be empty" CI gate needs two applies on the Floci side. Floci stores `default_tags` on distribution update, not on create. |
| 8 | `x-amz-server-side-encryption` | Not seen | `AES256` | Minor; default SSE-S3 shows on AWS only. |
| 9 | Reaching the site | `curl -H "Host: <distribution domain>" http://<vm>:4566/` (the domain has no DNS) | Real DNS | A browser needs wildcard DNS or a hosts entry locally. |
| 10 | RDS endpoint (side test, not in the module) | Reported `available` and started a real postgres sibling container, but the returned endpoint (`:7001`) refuses connections | Reachable endpoint | The emulator can report success without the behaviour behind it. |

Note on probing AWS anonymously: a 200 from `curl -L` on the S3 root is the marketing page, not data. Check `%{url_effective}` before believing a status code.

## Not gaps (same on both)

- `dynamodb_table` is deprecated in Terraform 1.16 in favour of `use_lockfile`. Both warn. `use_lockfile` on Floci is **untested**.
- The module is identical. Only `env.hcl` and the generated provider/backend differ.

## Traps hit on the way (blog material)

- A Floci image tag (`2.2.0-baseline`) can be **arm64-only** and fail to pull on amd64 ("no image found in image index"). Check with `podman manifest inspect` before pinning.
- HCL `? :` needs both sides to have the same type; use a filtered `for` expression instead of `cond ? {object} : {}`.
- `create-bucket` in `us-east-1` takes no `LocationConstraint`.
- The backend region and the provider region are separate concerns. A wrong region produced a `ResourceNotFoundException` on the lock table.
- An inline `# comment` pasted into an interactive zsh becomes grep arguments.
