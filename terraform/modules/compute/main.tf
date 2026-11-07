# Compute module: a static public IP, a network interface in the given subnet,
# and an Ubuntu 24.04 VM that only accepts SSH-key logins.

resource "azurerm_public_ip" "vm" {
  name                = "${var.name_prefix}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static" # IP stays the same across VM restarts
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "vm" {
  # Accepted risk: the VM needs a public IP so users can reach the website and
  # the team can SSH in. Exposure is limited by the NSG (22 only from
  # allowed_ssh_cidrs, 80 public, all else denied). The private-only
  # alternatives (Azure Bastion, a load balancer) cost more than our credits allow.
  #checkov:skip=CKV_AZURE_119:Public IP required for HTTP + team SSH; restricted by NSG (see SECURITY.md)
  name                = "${var.name_prefix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.name_prefix}-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = var.tags

  # Security: no passwords at all, only SSH keys.
  disable_password_authentication = true

  # Security: we configure the VM with Ansible, so Azure VM extensions
  # (a remote way to run code on the VM) are switched off.
  allow_extension_operations = false

  # One admin_ssh_key block per teammate's public key.
  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_keys
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Boot diagnostics with a Microsoft-managed storage account: lets you see
  # the serial console in the portal if the VM won't boot.
  boot_diagnostics {}

  lifecycle {
    # Fail early with a clear message instead of creating a VM nobody can log in to.
    precondition {
      condition     = length(var.ssh_public_keys) > 0
      error_message = "At least one SSH public key is required."
    }
  }
}
