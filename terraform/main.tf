# Root module: wires the network and compute modules together.
# Everything environment-specific comes from variables (see variables.tf).

locals {
  # e.g. "edushare-dev" -> edushare-dev-rg, edushare-dev-vnet, edushare-dev-vm ...
  name_prefix = "${var.project}-${var.environment}"

  # Tags on every resource make cost tracking and clean-up easy in the Azure portal.
  common_tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )

  # Read each teammate's public key file. pathexpand() turns "~" into the home folder.
  ssh_public_keys = [for p in var.ssh_public_key_paths : trimspace(file(pathexpand(p)))]
}

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "./modules/network"

  name_prefix           = local.name_prefix
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  vnet_address_space    = var.vnet_address_space
  subnet_address_prefix = var.subnet_address_prefix
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  app_port              = var.app_port
  tags                  = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_keys     = local.ssh_public_keys
  os_disk_size_gb     = var.os_disk_size_gb
  tags                = local.common_tags
}
