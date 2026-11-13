# Values printed after `terraform apply` and readable with `terraform output`.
# Ansible reads vm_public_ip and admin_username from here.

output "resource_group_name" {
  description = "Name of the resource group holding everything."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "Azure resource ID of the resource group."
  value       = azurerm_resource_group.main.id
}

output "vnet_id" {
  description = "Azure resource ID of the virtual network."
  value       = module.network.vnet_id
}

output "subnet_id" {
  description = "Azure resource ID of the application subnet."
  value       = module.network.subnet_id
}

output "nsg_id" {
  description = "Azure resource ID of the network security group."
  value       = module.network.nsg_id
}

output "vm_id" {
  description = "Azure resource ID of the virtual machine."
  value       = module.compute.vm_id
}

output "vm_public_ip" {
  description = "Public IP of the VM (put this in the Ansible inventory)."
  value       = module.compute.public_ip
}

output "vm_private_ip" {
  description = "Private IP of the VM inside the VNet."
  value       = module.compute.private_ip
}

output "admin_username" {
  description = "Linux user to SSH / run Ansible as."
  value       = var.admin_username
}

output "ssh_command" {
  description = "Copy-paste command to log in to the VM."
  value       = "ssh -i ~/.ssh/alu-devops ${var.admin_username}@${module.compute.public_ip}"
}

output "app_url" {
  description = "Where EduShare will be reachable once Ansible has deployed it."
  value       = var.app_port == 80 ? "http://${module.compute.public_ip}" : "http://${module.compute.public_ip}:${var.app_port}"
}
