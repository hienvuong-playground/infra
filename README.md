# Playground Infrastructure

This repository contains Terraform configuration for the playground environment on Azure. It uses two separate Terraform roots: `init` for bootstrap resources and `main` for the application infrastructure.

## Prerequisites

- Azure CLI installed and logged in: `az login`
- `Owner` and `Storage Blob Data Contributor` roles on the target Azure subscription

## Structure

- `init/` contains bootstrap resources such as the resource group and the storage account for Terraform state.
- `main/` contains the application infrastructure resources.

## GitHub token

The `init` root uses a GitHub token to write GitHub Actions organization variables. Create a classic personal access token at `https://github.com/settings/tokens` with the `admin:org` scope. Then create the file `init/secrets.tfvars` and add this line:

```
github_token = "your-token-here"
```

## Bootstrap (run once)

Run these commands from the `init/` directory.

```
terraform init -upgrade -reconfigure
terraform plan -var-file=secrets.tfvars -out tfplan
terraform apply tfplan
```
