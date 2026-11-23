variable "account_name" {
  description = "Globally unique Cosmos DB account name (lowercase, 3-44 chars)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the database."
  type        = string
}

variable "db_name" {
  description = "MongoDB database name."
  type        = string
}

variable "allowed_subnet_ids" {
  description = "Subnets allowed to reach the database (must have the Microsoft.AzureCosmosDB service endpoint)."
  type        = list(string)
}

variable "free_tier" {
  description = "Use the Cosmos DB free tier."
  type        = bool
}

variable "throughput" {
  description = "RU/s for the resources collection."
  type        = number
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
