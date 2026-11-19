# Values printed after `terraform apply` and readable with `terraform output`.
# Ansible and the CD pipeline read these names, so keep them stable.

# --- Where things are ---
output "resource_group_name" {
  description = "Resource group holding everything."
  value       = data.azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = module.network.vnet_id
}

output "public_subnet_id" {
  description = "ID of the public (bastion) subnet."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private (application) subnet."
  value       = module.network.private_subnet_id
}

# --- Access ---
output "admin_username" {
  description = "Linux user on both VMs (Ansible connects as this user)."
  value       = var.admin_username
}

output "bastion_public_ip" {
  description = "Public IP of the bastion: SSH entry point and website address."
  value       = module.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP of the bastion inside the VNet."
  value       = module.bastion.private_ip
}

output "app_vm_private_ip" {
  description = "Private IP of the app VM (reachable only through the bastion)."
  value       = module.app.private_ip
}

output "bastion_nsg_name" {
  description = "Bastion NSG name: the CD pipeline adds and removes its temporary SSH rule here."
  value       = module.network.public_nsg_name
}

output "nat_public_ip" {
  description = "Outbound IP the app VM uses to reach the internet."
  value       = module.network.nat_public_ip
}

output "ssh_bastion_command" {
  description = "Log in to the bastion."
  value       = "ssh -i ~/.ssh/alu-devops ${var.admin_username}@${module.bastion.public_ip}"
}

output "ssh_app_command" {
  description = "Log in to the private app VM by jumping through the bastion."
  value       = "ssh -i ~/.ssh/alu-devops -J ${var.admin_username}@${module.bastion.public_ip} ${var.admin_username}@${module.app.private_ip}"
}

output "app_url" {
  description = "Live website (served by Nginx on the bastion once Ansible has run)."
  value       = "http://${module.bastion.public_ip}"
}

# --- Registry ---
output "acr_name" {
  description = "Container registry name."
  value       = module.registry.name
}

output "acr_login_server" {
  description = "Registry address; the image is <acr_login_server>/edushare:<tag>."
  value       = module.registry.login_server
}

output "acr_admin_username" {
  description = "Registry username (for docker login on the VM)."
  value       = module.registry.admin_username
}

output "acr_admin_password" {
  description = "Registry password. Read with: terraform output -raw acr_admin_password"
  value       = module.registry.admin_password
  sensitive   = true
}

# --- Database ---
output "cosmos_account_name" {
  description = "Cosmos DB account name."
  value       = module.database.account_name
}

output "mongodb_connection_string" {
  description = "App connection string (MONGODB_URI). Read with: terraform output -raw mongodb_connection_string"
  value       = module.database.mongodb_connection_string
  sensitive   = true
}
