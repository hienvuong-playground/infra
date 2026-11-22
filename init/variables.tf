variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_app_pem" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "teams_alerts_webhook_url" {
  type      = string
  sensitive = true
}
