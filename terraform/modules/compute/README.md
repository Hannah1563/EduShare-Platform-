# Module: compute

Creates the EduShare virtual machine and its network connection:

- `azurerm_public_ip`: static Standard-SKU public IP (stays the same across restarts)
- `azurerm_network_interface`: NIC in the subnet from the network module
- `azurerm_linux_virtual_machine`: Ubuntu 24.04 LTS

## Security settings

| Setting | Why |
|---|---|
| `disable_password_authentication = true` | SSH keys only, so passwords can't be guessed |
| One `admin_ssh_key` per teammate (`dynamic` block) | Everyone uses their own key, and no private keys are shared |
| `allow_extension_operations = false` | No remote code execution through Azure VM extensions; Ansible configures the VM |
| `boot_diagnostics {}` | Serial console in the portal if the VM won't boot |
| `precondition` on `ssh_public_keys` | Refuses to create a VM nobody can log in to |

Checkov's `CKV_AZURE_119` (NIC has a public IP) is skipped on purpose: the public IP is needed for the website and team SSH, and the NSG limits what is reachable. See the comment in `main.tf` and the repo's `SECURITY.md`.

## Inputs

| Name | Type | Description |
|---|---|---|
| `name_prefix` | string | Prefix for resource names |
| `location` | string | Azure region |
| `resource_group_name` | string | Resource group to create resources in |
| `subnet_id` | string | Subnet for the NIC (from the network module) |
| `vm_size` | string | Azure VM size |
| `admin_username` | string | Linux admin user |
| `ssh_public_keys` | list(string) | Public key contents (not file paths) |
| `os_disk_size_gb` | number | OS disk size in GB |
| `tags` | map(string) | Tags for every resource (default `{}`) |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | ID of the VM |
| `public_ip` | Public IP address |
| `private_ip` | Private IP inside the VNet |
