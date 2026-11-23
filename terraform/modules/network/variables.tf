variable "name_prefix" {
  description = "Prefix for resource names, e.g. edushare-prod."
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
  description = "Address range of the virtual network."
  type        = list(string)
}

variable "public_subnet_prefix" {
  description = "Address range of the public (bastion) subnet."
  type        = string
}

variable "private_subnet_prefix" {
  description = "Address range of the private (application) subnet."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Public IPs allowed to SSH to the bastion."
  type        = list(string)
}

variable "app_port" {
  description = "Port the app listens on in the private subnet."
  type        = number
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway for the private subnet's outbound traffic."
  type        = bool
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
