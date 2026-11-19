# Compute module: one Ubuntu 24.04 VM that only accepts SSH-key logins.
# Used twice: for the bastion (public IP) and for the app VM (private only).

resource "azurerm_public_ip" "vm" {
  count               = var.assign_public_ip ? 1 : 0
  name                = "${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static" # IP stays the same across VM restarts
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "vm" {
  # Accepted risk (bastion only): the bastion needs a public IP to serve the
  # website and to be the single SSH entry point. The NSG limits SSH to the
  # team's IPs; the app VM itself never gets a public IP.
  #checkov:skip=CKV_AZURE_119:Only the bastion gets a public IP; SSH restricted by NSG (see SECURITY.md)
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.vm[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]
  tags                  = var.tags

  # Security: no passwords at all, only SSH keys.
  disable_password_authentication = true

  # Security: the VM is configured by Ansible, so Azure VM extensions
  # (a remote way to run code on the VM) are switched off.
  allow_extension_operations = false

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

  # Serial console in the portal if the VM won't boot.
  boot_diagnostics {}

  lifecycle {
    precondition {
      condition     = length(var.ssh_public_keys) > 0
      error_message = "At least one SSH public key is required."
    }
  }
}
