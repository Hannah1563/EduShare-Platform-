# Module: network

Creates the network the EduShare VM lives in:

- `azurerm_virtual_network`: the private address space
- `azurerm_subnet`: one subnet for the application
- `azurerm_network_security_group`: inbound firewall rules
- `azurerm_subnet_network_security_group_association`: applies the NSG to the whole subnet

## Firewall rules

Rules are defined as data in `locals.inbound_rules` and turned into `security_rule` blocks by a `dynamic` block. To open a new port, add one entry to that map.

| Rule | Priority | Port | Source |
|---|---|---|---|
| `allow-ssh-from-team` | 100 | 22 | `allowed_ssh_cidrs` only |
| `allow-http` | 110 | `app_port` (80) | Internet |
| *(Azure default)* `DenyAllInbound` | 65500 | any | any |

## Inputs

| Name | Type | Description |
|---|---|---|
| `name_prefix` | string | Prefix for resource names, e.g. `edushare-dev` |
| `location` | string | Azure region |
| `resource_group_name` | string | Resource group to create resources in |
| `vnet_address_space` | list(string) | VNet address range(s) |
| `subnet_address_prefix` | string | Subnet address range |
| `allowed_ssh_cidrs` | list(string) | CIDRs allowed to reach port 22 |
| `app_port` | number | Public website port |
| `tags` | map(string) | Tags for every resource (default `{}`) |

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | ID of the virtual network |
| `subnet_id` | ID of the subnet (passed to the compute module) |
| `nsg_id` | ID of the network security group |

## Example

```hcl
module "network" {
  source                = "./modules/network"
  name_prefix           = "edushare-dev"
  location              = "southafricanorth"
  resource_group_name   = azurerm_resource_group.main.name
  vnet_address_space    = ["10.10.0.0/16"]
  subnet_address_prefix = "10.10.1.0/24"
  allowed_ssh_cidrs     = ["41.186.205.191/32"]
  app_port              = 80
}
```
