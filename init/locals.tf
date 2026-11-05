locals {
  project_name         = "playground-init"
  project_name_no_dash = replace(local.project_name, "-", "")
  region               = "westeurope"

  # Numeric IDs (not names) go into the OIDC subject, so a recreated repo or org needs its new ID here.
  # Look up: gh api orgs/<org> --jq .id / gh api repos/<org>/<repo> --jq .id
  github_org = {
    name = "hienvuong-playground"
    id   = 325346053
  }
  github_repo_ids = {
    infra    = 1358361523
    frontend = 1358357400
    backend  = 1358360762
  }
}
