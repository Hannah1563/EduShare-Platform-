output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "public_subnet_id" {
  description = "ID of the public (bastion) subnet."
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private (application) subnet."
  value       = azurerm_subnet.private.id
}

output "public_nsg_name" {
  description = "Name of the bastion NSG (the CD pipeline adds its temporary SSH rule here)."
  value       = azurerm_network_security_group.public.name
}

output "public_nsg_id" {
  description = "ID of the bastion NSG."
  value       = azurerm_network_security_group.public.id
}

output "private_nsg_id" {
  description = "ID of the application NSG."
  value       = azurerm_network_security_group.private.id
}

output "nat_public_ip" {
  description = "Outbound public IP of the private subnet (null if no NAT gateway)."
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}
