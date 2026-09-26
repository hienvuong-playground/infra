## Init repo
* After the infra team provides the managed identity for working with the AKS data plane, update its details in `github_actions_variable`.
* Provide the `github_token` in `secrets.auto.tfvars`.
* Run Terraform in the init folder to apply the bootstrap configuration.
* Copy the client ID of the newly created managed identity to the Azure backend configuration in the `main` folder.
* When running GitHub Actions, `terraform init` uses OIDC, while `terraform plan` and `terraform apply` use the environment variables configured by `az login`.
* The `main` repo cannot be run locally because `terraform init` requires OIDC.
