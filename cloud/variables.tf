variable "teams_alerts_webhook_url" {
  description = "Teams Workflows webhook that receives alert cards. Set by init as the TEAMS_ALERTS_WEBHOOK_URL GitHub secret."
  type        = string
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = startswith(var.teams_alerts_webhook_url, "https://")
    error_message = "teams_alerts_webhook_url must be an https URL (is the TEAMS_ALERTS_WEBHOOK_URL secret set?)."
  }
}
