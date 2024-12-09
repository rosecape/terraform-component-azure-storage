data "azurerm_virtual_network" "main" {
  name                = var.virtual_network_name
  resource_group_name = var.resource_group_name
}

/* 
  This password will be reset by
  another automated process after the
  server is created. 
*/
resource "random_password" "pass" {
  length  = 32
  special = false
}

data "azurerm_key_vault" "core" {
  count = var.key_vault_name != null ? 1 : 0

  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_security_group" "psql_flexible_servers" {
  name                = "${var.storage_name}-psqlflexibleservers-nsg"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "psqlflexibleservers"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "psql_flexible_servers" {
  name                 = "${var.storage_name}-psqlflexibleservers"
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
  address_prefixes     = var.address_prefixes
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "psql_flexible_servers" {
  subnet_id                 = azurerm_subnet.psql_flexible_servers.id
  network_security_group_id = azurerm_network_security_group.psql_flexible_servers.id
}

resource "azurerm_private_dns_zone" "psql_flexible_servers" {
  name                = "${var.private_dns_zone_name}-pdz.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_subnet_network_security_group_association.psql_flexible_servers]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "${var.private_dns_zone_name}-pdzvnetlink.com"
  private_dns_zone_name = azurerm_private_dns_zone.psql_flexible_servers.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  resource_group_name   = var.resource_group_name
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = var.storage_name
  resource_group_name           = var.resource_group_name
  location                      = var.resource_group_location
  version                       = var.postgres_version
  delegated_subnet_id           = azurerm_subnet.psql_flexible_servers.id
  private_dns_zone_id           = azurerm_private_dns_zone.psql_flexible_servers.id
  administrator_login           = var.administrator_login
  administrator_password        = random_password.pass.result
  zone                          = "1"
  storage_mb                    = var.postgres_storage_mb
  sku_name                      = var.postgres_sku_name
  backup_retention_days         = 7
  public_network_access_enabled = false

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]

  lifecycle {
    ignore_changes = [
      administrator_password,
    ]
  }
}


resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "rosecape-operations-db"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "iceberg_rest_api" {
  name      = "iceberg-rest-api"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    prevent_destroy = true
  }

}

resource "azurerm_postgresql_flexible_server_database" "airflow" {
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_database" "superset" {
  name      = "superset"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "datalake" {
  name                = "${var.storage_name}datalake"
  resource_group_name = var.resource_group_name

  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  is_hns_enabled = true
}

resource "azurerm_storage_container" "warehouse" {
  name                  = "warehouse"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}


/* Temporary solution to store random generated password
    in a key vault secret. Rotation will be ensured by downstream
    automation. */
resource "azurerm_key_vault_secret" "metadata" {
  count = var.key_vault_name != null ? 1 : 0

  name = "metadata-connection"
  value = jsonencode({
    "id"                  = azurerm_postgresql_flexible_server.main.id
    "username"            = var.administrator_login
    "password"            = random_password.pass.result
    "server"              = azurerm_postgresql_flexible_server.main.fqdn
    "database"            = azurerm_postgresql_flexible_server_database.main.name
    "resource_group_name" = var.resource_group_name
    "METADATA_HOST"       = azurerm_postgresql_flexible_server.main.fqdn
    "METADATA_USER"       = var.administrator_login
    "METADATA_PASSWORD"   = random_password.pass.result
  })
  key_vault_id = data.azurerm_key_vault.core[0].id
}

resource "azurerm_key_vault_secret" "datalake" {
  count = var.key_vault_name != null ? 1 : 0

  name = "datalake-connection"
  value = jsonencode({
    "id"                       = azurerm_storage_account.datalake.id
    "access_key"               = azurerm_storage_account.datalake.primary_access_key
    "connection_string"        = azurerm_storage_account.datalake.primary_connection_string
    "AZURE_STORAGE_ACCESS_KEY" = azurerm_storage_account.datalake.primary_access_key
  })
  key_vault_id = data.azurerm_key_vault.core[0].id
}

resource "azurerm_key_vault_secret" "iceberg_rest_api" {
  count = var.key_vault_name != null ? 1 : 0

  name = "iceberg-jdbc-metadata-connection"
  value = jsonencode({
    "uri" : "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/iceberg-rest-api?user=${var.administrator_login}&password=${random_password.pass.result}",
  })
  key_vault_id = data.azurerm_key_vault.core[0].id
}
