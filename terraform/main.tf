# Root module: wires the network, two VMs, the managed database and the
# private container registry together. Everything environment-specific comes
# from variables (see variables.tf).
#
#   Internet --80--> bastion (public subnet, Nginx) --4000--> app VM (private subnet)
#   Team / CD --22--> bastion --22--> app VM            (Ansible jumps through the bastion)
#   app VM --> Cosmos DB (service endpoint)   app VM --> ACR (pull)   app VM --> NAT --> internet

locals {
  name_prefix = "${var.project}-${var.environment}" # e.g. edushare-prod

  common_tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )

  ssh_public_keys = [for p in var.ssh_public_key_paths : trimspace(file(pathexpand(p)))]

  # Registry and database names must be globally unique; a random suffix avoids clashes.
  unique_suffix = random_string.suffix.result
}

# The resource group already exists: the subscription owner created it and
# scoped the service principal to it (least privilege).
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

module "network" {
  source = "./modules/network"

  name_prefix           = local.name_prefix
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.main.name
  vnet_address_space    = var.vnet_address_space
  public_subnet_prefix  = var.public_subnet_prefix
  private_subnet_prefix = var.private_subnet_prefix
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  app_port              = var.app_port
  enable_nat_gateway    = var.enable_nat_gateway
  tags                  = local.common_tags
}

# Bastion / jumpbox: the only VM with a public IP. Serves the website through
# Nginx and is the single SSH entry point for the team and the CD pipeline.
module "bastion" {
  source = "./modules/compute"

  name                = "${local.name_prefix}-bastion-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = module.network.public_subnet_id
  assign_public_ip    = true
  vm_size             = var.bastion_vm_size
  admin_username      = var.admin_username
  ssh_public_keys     = local.ssh_public_keys
  os_disk_size_gb     = var.os_disk_size_gb
  tags                = merge(local.common_tags, { role = "bastion" })
}

# Application VM: private subnet only, no public IP.
module "app" {
  source = "./modules/compute"

  name                = "${local.name_prefix}-app-vm"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = module.network.private_subnet_id
  assign_public_ip    = false
  vm_size             = var.app_vm_size
  admin_username      = var.admin_username
  ssh_public_keys     = local.ssh_public_keys
  os_disk_size_gb     = var.os_disk_size_gb
  tags                = merge(local.common_tags, { role = "app" })
}

module "database" {
  source = "./modules/database"

  account_name        = "${local.name_prefix}-cosmos-${local.unique_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  db_name             = var.db_name
  allowed_subnet_ids  = [module.network.private_subnet_id]
  free_tier           = var.cosmos_free_tier
  throughput          = var.cosmos_throughput
  tags                = local.common_tags
}

module "registry" {
  source = "./modules/registry"

  name                = "${var.project}acr${local.unique_suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags
}
