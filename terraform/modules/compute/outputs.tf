output "vm_id" {
  description = "ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "public_ip" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "private_ip" {
  description = "Private IP address of the VM."
  value       = azurerm_network_interface.vm.private_ip_address
}
