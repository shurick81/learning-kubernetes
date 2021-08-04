variable "ARM_SUBSCRIPTION_ID" {}
variable "ARM_CLIENT_ID" {}
variable "ARM_CLIENT_SECRET" {}
variable "ARM_TENANT_ID" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.63.0"
    }
  }
}

provider "azurerm" {
  subscription_id               = var.ARM_SUBSCRIPTION_ID
  client_id                     = var.ARM_CLIENT_ID
  client_secret                 = var.ARM_CLIENT_SECRET
  tenant_id                     = var.ARM_TENANT_ID
  features {}
}

resource "azurerm_resource_group" "common" {
  name     = "kubernetes-lab-00"
  location = "westeurope"
}

resource "azurerm_virtual_network" "main" {
  name                = "kubernetes-vnet"
  address_space       = ["10.240.0.0/24"]
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
}

resource "azurerm_subnet" "main" {
  name                 = "kubernetes-subnet"
  resource_group_name  = azurerm_resource_group.common.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/24"]
}

resource "azurerm_route_table" "mainRoutes" {
  name                          = "kubernetes-routes"
  location                      = azurerm_resource_group.common.location
  resource_group_name           = azurerm_resource_group.common.name

  route {
    name                   = "kubernetes-route-10-200-0-0-24"
    address_prefix         = "10.200.0.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.20"
  }

  route {
    name                   = "kubernetes-route-10-200-1-0-24"
    address_prefix         = "10.200.1.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.240.0.21"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_route_table_association" "mainRoutes" {
  subnet_id      = azurerm_subnet.main.id
  route_table_id = azurerm_route_table.mainRoutes.id
}

resource "azurerm_network_security_group" "controller" {
  name                = "kubernetes-nsg"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  security_rule {
    name                       = "kubernetes-allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "kubernetes-allow-api-server"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_availability_set" "controller" {
  name                = "controller-as"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
}

resource "azurerm_public_ip" "lb00" {
  name                = "kubernetes-pip"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb00" {
  name                = "kubernetes-lb"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb00.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb00" {
  loadbalancer_id = azurerm_lb.lb00.id
  name            = "kubernetes-lb-pool"
}

resource "azurerm_lb_probe" "lb00" {
  resource_group_name = azurerm_resource_group.common.name
  loadbalancer_id     = azurerm_lb.lb00.id
  name                = "kubernetes-apiserver-probe"
  port                = 6443
}

resource "azurerm_lb_rule" "kube-api" {
  resource_group_name            = azurerm_resource_group.common.name
  loadbalancer_id                = azurerm_lb.lb00.id
  name                           = "kubernetes-apiserver-rule"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb00.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.lb00.id
}

module "CONTROLLER0" {
  source             = "./machines/controller"
  vm_id              = "0"
  rg_name            = azurerm_resource_group.common.name
  vnet               = azurerm_virtual_network.main.id
  subnet             = azurerm_subnet.main.id
  security_group     = azurerm_network_security_group.controller.id
  availability_set   = azurerm_availability_set.controller.id
  pool               = azurerm_lb_backend_address_pool.lb00.id
}

module "CONTROLLER1" {
  source             = "./machines/controller"
  vm_id              = "1"
  rg_name            = azurerm_resource_group.common.name
  vnet               = azurerm_virtual_network.main.id
  subnet             = azurerm_subnet.main.id
  security_group     = azurerm_network_security_group.controller.id
  availability_set   = azurerm_availability_set.controller.id
  pool               = azurerm_lb_backend_address_pool.lb00.id
}

module "CONTROLLER2" {
  source             = "./machines/controller"
  vm_id              = "2"
  rg_name            = azurerm_resource_group.common.name
  vnet               = azurerm_virtual_network.main.id
  subnet             = azurerm_subnet.main.id
  security_group     = azurerm_network_security_group.controller.id
  availability_set   = azurerm_availability_set.controller.id
  pool               = azurerm_lb_backend_address_pool.lb00.id
}

resource "azurerm_network_security_group" "worker" {
  name                = "kubernetes-worker-nsg"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  security_rule {
    name                       = "kubernetes-allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "kubernetes-allow-health"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "kubernetes-allow-service"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_availability_set" "worker" {
  name                = "worker-as"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
}

resource "azurerm_public_ip" "lb01" {
  name                = "kubernetes-worker-lb-pip"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb01" {
  name                = "kubernetes-worker-lb"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb01.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb01" {
  loadbalancer_id = azurerm_lb.lb01.id
  name            = "kubernetes-worker-lb-pool"
}

resource "azurerm_lb_probe" "lb01" {
  resource_group_name = azurerm_resource_group.common.name
  loadbalancer_id     = azurerm_lb.lb01.id
  name                = "kubernetes-worker-probe"
  port                = 10250
}

resource "azurerm_lb_rule" "kube-worker" {
  resource_group_name            = azurerm_resource_group.common.name
  loadbalancer_id                = azurerm_lb.lb01.id
  name                           = "kubernetes-worker-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb01.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.lb01.id
}

module "WORKER0" {
  source             = "./machines/worker"
  vm_id              = "0"
  rg_name            = azurerm_resource_group.common.name
  vnet               = azurerm_virtual_network.main.id
  subnet             = azurerm_subnet.main.id
  security_group     = azurerm_network_security_group.worker.id
  availability_set   = azurerm_availability_set.worker.id
  pool               = azurerm_lb_backend_address_pool.lb01.id
}

module "WORKER1" {
  source             = "./machines/worker"
  vm_id              = "1"
  rg_name            = azurerm_resource_group.common.name
  vnet               = azurerm_virtual_network.main.id
  subnet             = azurerm_subnet.main.id
  security_group     = azurerm_network_security_group.worker.id
  availability_set   = azurerm_availability_set.worker.id
  pool               = azurerm_lb_backend_address_pool.lb01.id
}
