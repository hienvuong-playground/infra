data "cloudflare_zone" "main" {
  filter = {
    name = "hienvuong.com"
  }
}

resource "cloudflare_dns_record" "apex" {
  zone_id = data.cloudflare_zone.main.id
  name    = data.cloudflare_zone.main.name
  type    = "A"
  content = azurerm_public_ip.gateway.ip_address
  ttl     = 1
  proxied = true
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.main.id
  name    = "*.${data.cloudflare_zone.main.name}"
  type    = "A"
  content = azurerm_public_ip.gateway.ip_address
  ttl     = 1
  proxied = true
}

# Edge → origin over HTTPS with the origin cert validated (ADR 0013).
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = data.cloudflare_zone.main.id
  setting_id = "ssl"
  value      = "strict"
}

# DNS-01 solver. Permission group IDs from GET /accounts/{account_id}/tokens/permission_groups.
resource "cloudflare_account_token" "cert_manager" {
  account_id = data.cloudflare_zone.main.account.id
  name       = "cert-manager"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
    ]
    resources = jsonencode({ "com.cloudflare.api.account.zone.${data.cloudflare_zone.main.id}" = "*" })
  }]
}

resource "azurerm_key_vault_secret" "cloudflare_cert_manager_token" {
  name         = "cloudflare-cert-manager-token"
  value        = cloudflare_account_token.cert_manager.value
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.current_user_kv_admin]
}

resource "azurerm_role_assignment" "cert_manager_cloudflare_token" {
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault_secret.cloudflare_cert_manager_token.resource_versionless_id
}

# Challenges only the storefront's HTML. Challenges break fetch/XHR, so api, grafana, flux and the
# hashed assets are left out (ADR 0018).
resource "cloudflare_ruleset" "waf_custom" {
  zone_id = data.cloudflare_zone.main.id
  name    = "default"
  phase   = "http_request_firewall_custom"
  kind    = "zone"

  rules = [{
    ref         = "challenge_www"
    description = "Managed Challenge on www HTML"
    expression  = "(http.host eq \"www.${data.cloudflare_zone.main.name}\" and not starts_with(http.request.uri.path, \"/assets/\"))"
    action      = "managed_challenge"
  }]
}
