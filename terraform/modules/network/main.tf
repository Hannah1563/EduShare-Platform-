# Network module: one VNet with two subnets.
#   public  subnet -> bastion / web entry VM (the only machine with a public IP)
#   private subnet -> application VM (reachable only from the public subnet)
# Each subnet has its own NSG. Rules are separate resources (not inline blocks)
# so the CD pipeline can add and remove its temporary SSH rule without
# Terraform wiping it, and Terraform never deletes rules it does not own.

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "public" {
  name                 = "${var.name_prefix}-public-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.public_subnet_prefix]
}

resource "azurerm_subnet" "private" {
  name                 = "${var.name_prefix}-private-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.private_subnet_prefix]

  # Truly private: no implicit outbound IP. Outbound goes through the NAT gateway.
  default_outbound_access_enabled = !var.enable_nat_gateway

  # Lets the database accept traffic from this subnet only (see database module).
  service_endpoints = ["Microsoft.AzureCosmosDB"]
}

# ---------------------------------------------------------------------------
# NAT gateway: outbound-only internet for the private VM (apt, Docker, ACR)
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${var.name_prefix}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${var.name_prefix}-natgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

# ---------------------------------------------------------------------------
# Public subnet NSG (bastion / web entry)
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "public" {
  name                = "${var.name_prefix}-public-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# SSH only from the team's IPs. The CD pipeline adds its own runner IP as a
# temporary rule (priority 150) during a deploy and removes it afterwards.
resource "azurerm_network_security_rule" "public_ssh_from_team" {
  name                        = "allow-ssh-from-team"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidrs
  destination_address_prefix  = var.public_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# Public website: Nginx on the bastion forwards to the private app VM.
resource "azurerm_network_security_rule" "public_http" {
  #checkov:skip=CKV_AZURE_160:Port 80 must be open to the internet: it serves the public website (see SECURITY.md)
  name                        = "allow-http-from-internet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = var.public_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public.id
}

# ---------------------------------------------------------------------------
# Private subnet NSG (application VM)
# ---------------------------------------------------------------------------

resource "azurerm_network_security_group" "private" {
  name                = "${var.name_prefix}-private-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# SSH only from the bastion's subnet (Ansible jumps through the bastion).
resource "azurerm_network_security_rule" "private_ssh_from_bastion" {
  name                        = "allow-ssh-from-bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.public_subnet_prefix
  destination_address_prefix  = var.private_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# App traffic only from the bastion's Nginx reverse proxy.
resource "azurerm_network_security_rule" "private_app_from_bastion" {
  name                        = "allow-app-from-bastion"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.app_port)
  source_address_prefix       = var.public_subnet_prefix
  destination_address_prefix  = var.private_subnet_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# Azure's default rules allow all traffic inside the VNet. Block everything
# else explicitly, so only the two rules above can reach the app VM.
resource "azurerm_network_security_rule" "private_deny_vnet" {
  name                        = "deny-all-other-vnet-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}
