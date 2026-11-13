# Network module: virtual network, one subnet, and a network security group
# (Azure's firewall) attached to that subnet.

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "${var.name_prefix}-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]
}

locals {
  # Inbound rules as data. Adding a rule = adding an entry here;
  # the dynamic block below turns each entry into a security_rule.
  # Anything not listed is blocked by Azure's default DenyAllInbound rule.
  inbound_rules = {
    allow-ssh-from-team = {
      priority = 100
      port     = "22"
      sources  = var.allowed_ssh_cidrs
    }
    allow-http = {
      priority = 110
      port     = tostring(var.app_port)
      sources  = ["Internet"]
    }
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "${var.name_prefix}-app-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.inbound_rules
    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.port
      source_address_prefixes    = length(security_rule.value.sources) > 1 ? security_rule.value.sources : null
      source_address_prefix      = length(security_rule.value.sources) == 1 ? security_rule.value.sources[0] : null
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

# Attaching the NSG to the subnet protects every VM placed in it.
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
