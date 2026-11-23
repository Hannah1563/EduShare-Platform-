# ---------------------------------------------------------------------------
# Naming and placement
# ---------------------------------------------------------------------------

variable "project" {
  description = "Short project name, used as a prefix for every resource name."
  type        = string
  default     = "edushare"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "project must be 3-20 characters: lowercase letters, numbers and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. Becomes part of resource names and tags."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "resource_group_name" {
  description = "Existing resource group to deploy into. Created once by the subscription owner, and the only scope the service principal can manage."
  type        = string
}

variable "location" {
  description = "Azure region, e.g. southafricanorth. No default on purpose: you must choose one."
  type        = string
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address range of the virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "public_subnet_prefix" {
  description = "Public subnet: holds only the bastion / web entry VM."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_prefix" {
  description = "Private subnet: holds the application VM. No public IPs here."
  type        = string
  default     = "10.20.2.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "Public IPs (CIDR) allowed to SSH to the bastion, e.g. [\"102.22.168.143/32\"]. One per teammate."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0 && alltrue([for c in var.allowed_ssh_cidrs : can(cidrhost(c, 0))])
    error_message = "allowed_ssh_cidrs must contain at least one valid CIDR, e.g. 1.2.3.4/32."
  }

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Opening SSH to the whole internet (0.0.0.0/0) is not allowed."
  }
}

variable "app_port" {
  description = "Port the app container listens on inside the private VM (Express PORT)."
  type        = number
  default     = 4000
}

variable "enable_nat_gateway" {
  description = "Give the private subnet outbound internet (apt, Docker, ACR pulls) through a NAT gateway. If false, Azure's default outbound access is used instead."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Virtual machines
# ---------------------------------------------------------------------------

variable "app_vm_size" {
  description = "Size of the private application VM."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "bastion_vm_size" {
  description = "Size of the bastion / web entry VM (the smallest size this subscription allows)."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "admin_username" {
  description = "Linux admin user on both VMs (Ansible connects as this user)."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_paths" {
  description = "Paths to SSH PUBLIC keys allowed to log in. One per teammate, plus the CD pipeline's key."
  type        = list(string)
  default     = ["~/.ssh/alu-devops.pub"]
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for each VM."
  type        = number
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 128
    error_message = "os_disk_size_gb must be between 30 and 128."
  }
}

# ---------------------------------------------------------------------------
# Managed database (Azure Cosmos DB for MongoDB)
# ---------------------------------------------------------------------------

variable "db_name" {
  description = "MongoDB database name the app uses."
  type        = string
  default     = "edushare"
}

variable "cosmos_free_tier" {
  description = "Use the Cosmos DB free tier (1000 RU/s, 25 GB). Only one free-tier account is allowed per subscription."
  type        = bool
  default     = true
}

variable "cosmos_throughput" {
  description = "Provisioned throughput (RU/s) for the resources collection. 400 is the minimum and fits in the free tier."
  type        = number
  default     = 400
}
