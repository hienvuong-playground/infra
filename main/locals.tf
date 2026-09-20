locals {
  project_name = "playground"
  region       = "westeurope"
  sa_keyvault_name = "sa-kv"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}
