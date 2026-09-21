# resource "azurerm_user_assigned_identity" "k8s" {
#   location            = azurerm_resource_group.main.location
#   name                = "id-${local.project_name}-k8s"
#   resource_group_name = azurerm_resource_group.main.name
# }

# resource "azurerm_federated_identity_credential" "k8s" {
#   name                      = "k8s"
#   audience                  = ["api://AzureADTokenExchange"]
#   issuer                    = "https://token.actions.githubusercontent.com"
#   user_assigned_identity_id = azurerm_user_assigned_identity.k8s.id
#   subject                   = "repo:hienvuong-playground@325346053/infra@1378931138:ref:refs/heads/main"
# }

# resource "azurerm_role_assignment" "owner" {
#   principal_id         = azurerm_user_assigned_identity.k8s.principal_id
#   role_definition_name = "Owner"
#   scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
# }
