output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "ID of the application subnet (the compute module places the VM here)."
  value       = azurerm_subnet.app.id
}

output "nsg_id" {
  description = "ID of the network security group."
  value       = azurerm_network_security_group.app.id
}
