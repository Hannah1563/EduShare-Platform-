output "vm_id" {
  description = "ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.vm.name
}

output "public_ip" {
  description = "Public IP address (null for a private VM)."
  value       = var.assign_public_ip ? azurerm_public_ip.vm[0].ip_address : null
}

output "private_ip" {
  description = "Private IP address inside the VNet."
  value       = azurerm_network_interface.vm.private_ip_address
}
