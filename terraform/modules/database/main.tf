# Managed database: Azure Cosmos DB with the MongoDB API.
# The app keeps using Mongoose unchanged; only its connection string changes.

resource "azurerm_cosmosdb_account" "main" {
  #checkov:skip=CKV_AZURE_100:Customer-managed keys are not needed at this scale; data is encrypted at rest with Microsoft-managed keys
  #checkov:skip=CKV_AZURE_140:The MongoDB driver authenticates with account keys; Entra ID auth is not supported for the Mongo API
  #checkov:skip=CKV_AZURE_101:Public endpoint stays on but is locked to the private subnet by the VNet filter below (private endpoints cost extra)
  name                = var.account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  free_tier_enabled    = var.free_tier
  mongo_server_version = "4.2"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # Network lock-down: only the private (app) subnet can connect.
  is_virtual_network_filter_enabled = true

  dynamic "virtual_network_rule" {
    for_each = var.allowed_subnet_ids
    content {
      id = virtual_network_rule.value
    }
  }

  # Data-plane users cannot change account settings with keys.
  access_key_metadata_writes_enabled = false

  tags = var.tags
}

resource "azurerm_cosmosdb_mongo_database" "main" {
  name                = var.db_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# The app's only collection (Mongoose model "Resource" -> collection "resources").
resource "azurerm_cosmosdb_mongo_collection" "resources" {
  name                = "resources"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_mongo_database.main.name
  throughput          = var.throughput

  index {
    keys   = ["_id"]
    unique = true
  }

  # Cosmos DB needs a compound index to sort on two fields
  # (the app sorts by helpfulCount, then _id).
  index {
    keys = ["helpfulCount", "_id"]
  }

  # Supports the subject/level filters on the Resources page.
  index {
    keys = ["subject", "level"]
  }
}
