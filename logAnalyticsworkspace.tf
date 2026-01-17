#log analytics workspace in central indai
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-tls-capture-central"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  depends_on = [ azurerm_resource_group.name, azurerm_storage_account.storageaccount1, azurerm_storage_account.storageaccount2 ]
}