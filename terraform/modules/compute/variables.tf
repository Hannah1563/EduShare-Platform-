variable "name_prefix" {
  description = "Prefix for resource names, e.g. edushare-dev."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create the VM in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the VM's network interface joins."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
}

variable "admin_username" {
  description = "Linux admin user."
  type        = string
}

variable "ssh_public_keys" {
  description = "Contents of the SSH public keys allowed to log in."
  type        = list(string)
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
