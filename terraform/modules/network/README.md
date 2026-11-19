# network module

One VNet with a **public subnet** (bastion only) and a **private subnet** (app VM), a NAT gateway for the private subnet's outbound traffic, and one NSG per subnet.

- Public NSG: SSH (22) from `allowed_ssh_cidrs`, HTTP (80) from the internet.
- Private NSG: SSH (22) and the app port (4000) from the public subnet only; all other VNet traffic denied.
- Rules are separate `azurerm_network_security_rule` resources, so the CD pipeline can add a temporary rule without Terraform removing it.
- The private subnet has the `Microsoft.AzureCosmosDB` service endpoint so the database can be locked to it.

Outputs: `vnet_id`, `public_subnet_id`, `private_subnet_id`, `public_nsg_name`, `public_nsg_id`, `private_nsg_id`, `nat_public_ip`.
