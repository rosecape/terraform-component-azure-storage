variable "address_prefixes" {
  type        = list(string)
  description = "The address prefixes for the subnet"
  default     = []
}

variable "administrator_login" {
  type        = string
  description = "The administrator login for the PostgreSQL server"
}

variable "administrator_password" {
  type        = string
  description = "The administrator password for the PostgreSQL server"
  default     = null
}

variable "postgres_sku_name" {
  type        = string
  description = "The SKU name for the PostgreSQL server"
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type        = number
  description = "The storage capacity of the PostgreSQL server in MB"
  default     = 32768
}

variable "postgres_version" {
  type        = string
  description = "The version of PostgreSQL to use"
  default     = "13"
}

variable "private_dns_zone_name" {
  type        = string
  description = "The name of the private DNS zone"
}

variable "resource_group_location" {
  type        = string
  description = "The location of the resource group"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "storage_name" {
  type        = string
  description = "The name of the database component"
}

# variable "storage_private_dns_zone" {
#   type        = string
#   description = "The private DNS zone for the storage account"
# }

variable "key_vault_name" {
  type        = string
  description = "The name of the key vault"
  default     = null
}

variable "virtual_network_id" {
  description = "The ID of the virtual network"
  type        = string
  default     = null
}

variable "virtual_network_name" {
  type        = string
  description = "The name of the virtual network"
}
