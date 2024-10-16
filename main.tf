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
  length = 32
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
