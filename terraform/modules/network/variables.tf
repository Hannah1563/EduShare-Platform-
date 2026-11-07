variable "name_prefix" {
  description = "Prefix for resource names, e.g. edushare-dev."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to create the network in."
  type        = string
}

variable "vnet_address_space" {
  description = "Address range(s) of the virtual network."
  type        = list(string)
}

variable "subnet_address_prefix" {
  description = "Address range of the application subnet."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to reach port 22."
  type        = list(string)
}

variable "app_port" {
  description = "Public port for the website."
  type        = number
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
