output "name" {
  description = "Registry name."
  value       = azurerm_container_registry.main.name
}

output "id" {
  description = "Registry ID."
  value       = azurerm_container_registry.main.id
}

output "login_server" {
  description = "Registry address, e.g. edushareacr1234.azurecr.io."
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "Pull/push username."
  value       = azurerm_container_registry.main.admin_username
}

output "admin_password" {
  description = "Pull/push password."
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}
