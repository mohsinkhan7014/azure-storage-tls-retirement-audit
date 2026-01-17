# three storee account 
resource "azurerm_storage_account" "storageaccount1" {
  name                     = "makranaappst1"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version = "TLS1_0"

  depends_on = [ azurerm_resource_group.name ]
}

resource "azurerm_storage_account" "storageaccount2" {
  name                     = "makranaappst2"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
    min_tls_version = "TLS1_1"
  depends_on = [ azurerm_resource_group.name ]
}

