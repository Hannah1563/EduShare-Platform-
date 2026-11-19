output "account_name" {
  description = "Cosmos DB account name."
  value       = azurerm_cosmosdb_account.main.name
}

output "account_id" {
  description = "Cosmos DB account ID."
  value       = azurerm_cosmosdb_account.main.id
}

output "mongodb_connection_string" {
  description = "Connection string for the app, with the database name added (Mongoose reads it from MONGODB_URI)."
  # Azure's string looks like mongodb://user:key@host:10255/?ssl=true&...
  # Inserting the database name after the host keeps Mongoose's default database correct.
  value     = replace(azurerm_cosmosdb_account.main.primary_mongodb_connection_string, "/?", "/${var.db_name}?")
  sensitive = true
}
