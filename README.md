# Playground Infrastructure

This repository contains Terraform configuration for the playground environment on Azure. It uses two separate Terraform roots: `init` for bootstrap resources and `main` for the application infrastructure.

## Prerequisites

Rights the person running `init` must hold (init can't grant these to itself):

- Azure CLI installed and logged in: `az login`
- Azure: `Owner` on the target subscription, to create the role assignments for the CI identity.
- Entra: `Global Administrator`, to assign the `Application Administrator` and `Directory Readers` directory roles to the CI identity.
- GitHub: owner of the `hienvuong-playground` org, with a classic PAT scoped `admin:org` and `repo` (see below).
- Cloudflare: a hand-made account token `infra-ci` (permissions in ADR 0018).

`init/bootstrap.sh` checks all of these first.

## Structure

- `init/` contains bootstrap resources such as the resource group and the storage account for Terraform state.
- `main/` contains the application infrastructure resources.

## Manual steps before init

1. **GitHub token.** `init` uses it to write GitHub Actions org variables and secrets. Create a classic personal access token at `https://github.com/settings/tokens` with the `admin:org` and `repo` scopes (`repo` is for the repo-level Actions settings).
2. **GitHub App** (used by `k8s/terraform` to manage deploy keys, see ADR 0003). Create it in the org settings → Developer settings → GitHub Apps:
   - Repository permissions: only `Administration: Read and write`. No webhook.
   - Install it on the org, for the `backend`, `frontend` and `infra` repos.
   - Generate a private key (PEM).
   - Put the App ID and installation ID in `k8s/terraform/providers.tf`.
3. Create `init/secrets.auto.tfvars`:

```
github_token   = "your-token-here"
github_app_pem = <<EOT
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
EOT
cloudflare_api_token = "..."
```

Init pushes the PEM to the org secret `GH_APP_PEM` (visible to `infra` only). To rotate the key, change the file and rerun init.

## Bootstrap (run once)

Run these commands from the `init/` directory.

```
./bootstrap.sh # registers resource providers, creates the storage account for init's own state
terraform init -upgrade -reconfigure -backend-config=../terraform-backend/init.tfbackend
terraform plan -out tfplan # no var-file flag needed, secrets.auto.tfvars is loaded automatically
terraform apply tfplan
```
