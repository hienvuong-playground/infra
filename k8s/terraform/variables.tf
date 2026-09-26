variable "github_app_pem" {
  type        = string
  sensitive   = true
  default     = null
  description = "GitHub App private key (PEM contents). Set via TF_VAR_github_app_pem in CI; falls back to the local pem file when unset."
}
