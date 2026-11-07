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
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region to deploy into, e.g. southafricanorth. No default on purpose: you must choose one."
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
  default     = ["10.10.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address range of the application subnet (must be inside the VNet range)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "Public IPs (CIDR) allowed to SSH to the VM, e.g. [\"41.186.205.191/32\"]. Add each teammate's IP."
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
  description = "Public port the website is served on. Ansible maps this to the container's port 4000."
  type        = number
  default     = 80
}

# ---------------------------------------------------------------------------
# Virtual machine
# ---------------------------------------------------------------------------

variable "vm_size" {
  description = "Azure VM size. If Azure reports SkuNotAvailable, try another size or region."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "admin_username" {
  description = "Linux admin user created on the VM (Ansible connects as this user)."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_paths" {
  description = "Paths to SSH PUBLIC keys allowed to log in. One per teammate."
  type        = list(string)
  default     = ["~/.ssh/alu-devops.pub"]
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB (Docker images and MongoDB data live here)."
  type        = number
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 128
    error_message = "os_disk_size_gb must be between 30 and 128."
  }
}
