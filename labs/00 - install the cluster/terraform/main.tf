variable "ARM_SUBSCRIPTION_ID" {}
variable "ARM_CLIENT_ID" {}
variable "ARM_CLIENT_SECRET" {}
variable "ARM_TENANT_ID" {}
variable "VM_ADMIN_PASSWORD" {}

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
  name                = "common"
  address_space       = ["10.0.0.0/16"]
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
}

resource "azurerm_subnet" "main" {
  name                 = "mainSubnet"
  resource_group_name  = azurerm_resource_group.common.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "main" {
  name                = "common"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  security_rule {
    name                       = "SSH"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vm00" {
  name                = "vm00"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
  allocation_method   = "Dynamic"
  domain_name_label   = "kubernetes-lab-slkdfjh-vm00"
}

# Create network interface
resource "azurerm_network_interface" "vm00" {
  name                      = "vm00"
  location                  = "westeurope"
  resource_group_name       = azurerm_resource_group.common.name

  ip_configuration {
    name                          = "mainNicConfiguration"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.vm00.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm00" {
    network_interface_id      = azurerm_network_interface.vm00.id
    network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "lb00" {
  name                = "Loadbalancer00"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb00" {
  name                = "TestLoadBalancer"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb00.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb00" {
  loadbalancer_id = azurerm_lb.lb00.id
  name            = "BackEndAddressPool00"
}

resource "azurerm_lb_probe" "lb00" {
  resource_group_name = azurerm_resource_group.common.name
  loadbalancer_id     = azurerm_lb.lb00.id
  name                = "port-6443"
  port                = 6443
}

resource "azurerm_lb_rule" "kube-api" {
  resource_group_name            = azurerm_resource_group.common.name
  loadbalancer_id                = azurerm_lb.lb00.id
  name                           = "kube-api"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb00.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.lb00.id
}

resource "azurerm_lb_nat_pool" "lb00" {
  resource_group_name            = azurerm_resource_group.common.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.lb00.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_virtual_machine_scale_set" "scale-set-00" {
  name                = "scale-set-00"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.common.name

  upgrade_policy_mode  = "Manual"

  sku {
    name     = "Standard_A2_v2"
    tier     = "Standard"
    capacity = 3
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "20.04.202105130"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "slazvm"
    admin_username       = "aleks"
    admin_password       = var.VM_ADMIN_PASSWORD
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "main"
    primary = true

    ip_configuration {
      name                                   = "MainConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.main.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb00.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lb00.id]
    }
  }

}

# Create virtual machine
#resource "azurerm_virtual_machine" "vm00" {
#  name                          = "slazvm00"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm00.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm00-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0001-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm00.domain_name_label}.${azurerm_public_ip.vm00.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}
#
#resource "azurerm_public_ip" "vm01" {
#  name                = "vm01"
#  location            = "westeurope"
#  resource_group_name = azurerm_resource_group.common.name
#  allocation_method   = "Dynamic"
#  domain_name_label   = "kubernetes-lab-slkdfjh-vm01"
#}
#
## Create network interface
#resource "azurerm_network_interface" "vm01" {
#  name                      = "vm01"
#  location                  = "westeurope"
#  resource_group_name       = azurerm_resource_group.common.name
#
#  ip_configuration {
#    name                          = "mainNicConfiguration"
#    subnet_id                     = azurerm_subnet.main.id
#    private_ip_address_allocation = "dynamic"
#    public_ip_address_id          = azurerm_public_ip.vm01.id
#  }
#}
#
#resource "azurerm_network_interface_security_group_association" "vm01" {
#    network_interface_id      = azurerm_network_interface.vm01.id
#    network_security_group_id = azurerm_network_security_group.main.id
#}
#
## Create virtual machine
#resource "azurerm_virtual_machine" "vm01" {
#  name                          = "slazvm01"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm01.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm01-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0001-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm01.domain_name_label}.${azurerm_public_ip.vm01.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}

#resource "azurerm_public_ip" "vm02" {
#  name                = "vm02"
#  location            = "westeurope"
#  resource_group_name = azurerm_resource_group.common.name
#  allocation_method   = "Dynamic"
#  domain_name_label   = "kubernetes-lab-slkdfjh-vm02"
#}
#
## Create network interface
#resource "azurerm_network_interface" "vm02" {
#  name                      = "vm02"
#  location                  = "westeurope"
#  resource_group_name       = azurerm_resource_group.common.name
#
#  ip_configuration {
#    name                          = "mainNicConfiguration"
#    subnet_id                     = azurerm_subnet.main.id
#    private_ip_address_allocation = "dynamic"
#    public_ip_address_id          = azurerm_public_ip.vm02.id
#  }
#}
#
#resource "azurerm_network_interface_security_group_association" "vm02" {
#    network_interface_id      = azurerm_network_interface.vm02.id
#    network_security_group_id = azurerm_network_security_group.main.id
#}
#
## Create virtual machine
#resource "azurerm_virtual_machine" "vm02" {
#  name                          = "slazvm02"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm02.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm02-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0002-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm02.domain_name_label}.${azurerm_public_ip.vm02.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}
#
#resource "azurerm_public_ip" "vm03" {
#  name                = "vm03"
#  location            = "westeurope"
#  resource_group_name = azurerm_resource_group.common.name
#  allocation_method   = "Dynamic"
#  domain_name_label   = "kubernetes-lab-slkdfjh-vm03"
#}
#
## Create network interface
#resource "azurerm_network_interface" "vm03" {
#  name                      = "vm03"
#  location                  = "westeurope"
#  resource_group_name       = azurerm_resource_group.common.name
#
#  ip_configuration {
#    name                          = "mainNicConfiguration"
#    subnet_id                     = azurerm_subnet.main.id
#    private_ip_address_allocation = "dynamic"
#    public_ip_address_id          = azurerm_public_ip.vm03.id
#  }
#}
#
#resource "azurerm_network_interface_security_group_association" "vm03" {
#    network_interface_id      = azurerm_network_interface.vm03.id
#    network_security_group_id = azurerm_network_security_group.main.id
#}
#
## Create virtual machine
#resource "azurerm_virtual_machine" "vm03" {
#  name                          = "slazvm03"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm03.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm03-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0003-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm03.domain_name_label}.${azurerm_public_ip.vm03.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}
#
#resource "azurerm_public_ip" "vm04" {
#  name                = "vm04"
#  location            = "westeurope"
#  resource_group_name = azurerm_resource_group.common.name
#  allocation_method   = "Dynamic"
#  domain_name_label   = "kubernetes-lab-slkdfjh-vm04"
#}
#
## Create network interface
#resource "azurerm_network_interface" "vm04" {
#  name                      = "vm04"
#  location                  = "westeurope"
#  resource_group_name       = azurerm_resource_group.common.name
#
#  ip_configuration {
#    name                          = "mainNicConfiguration"
#    subnet_id                     = azurerm_subnet.main.id
#    private_ip_address_allocation = "dynamic"
#    public_ip_address_id          = azurerm_public_ip.vm04.id
#  }
#}
#
#resource "azurerm_network_interface_security_group_association" "vm04" {
#    network_interface_id      = azurerm_network_interface.vm04.id
#    network_security_group_id = azurerm_network_security_group.main.id
#}
#
## Create virtual machine
#resource "azurerm_virtual_machine" "vm04" {
#  name                          = "slazvm04"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm04.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm04-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0004-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm04.domain_name_label}.${azurerm_public_ip.vm04.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}
#
#resource "azurerm_public_ip" "vm05" {
#  name                = "vm05"
#  location            = "westeurope"
#  resource_group_name = azurerm_resource_group.common.name
#  allocation_method   = "Dynamic"
#  domain_name_label   = "kubernetes-lab-slkdfjh-vm05"
#}
#
## Create network interface
#resource "azurerm_network_interface" "vm05" {
#  name                      = "vm05"
#  location                  = "westeurope"
#  resource_group_name       = azurerm_resource_group.common.name
#
#  ip_configuration {
#    name                          = "mainNicConfiguration"
#    subnet_id                     = azurerm_subnet.main.id
#    private_ip_address_allocation = "dynamic"
#    public_ip_address_id          = azurerm_public_ip.vm05.id
#  }
#}
#
#resource "azurerm_network_interface_security_group_association" "vm05" {
#    network_interface_id      = azurerm_network_interface.vm05.id
#    network_security_group_id = azurerm_network_security_group.main.id
#}
#
## Create virtual machine
#resource "azurerm_virtual_machine" "vm05" {
#  name                          = "slazvm05"
#  location                      = "westeurope"
#  resource_group_name           = azurerm_resource_group.common.name
#  network_interface_ids         = [azurerm_network_interface.vm05.id]
#  vm_size                       = "Standard_A2_v2"
#  delete_os_disk_on_termination = true
#
#  storage_os_disk {
#    name              = "vm05-os"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
#
#  storage_image_reference {
#    publisher = "Canonical"
#    offer     = "0005-com-ubuntu-server-focal"
#    sku       = "20_04-lts"
#    version   = "20.04.202105130"
#  }
# 
#  os_profile {
#    computer_name  = "vm-dev"
#    admin_username = "aleks"
#    admin_password = var.VM_ADMIN_PASSWORD
#  }
#
#  os_profile_linux_config {
#    disable_password_authentication = false
#  }
#
#  provisioner "remote-exec" {
#    connection {
#      host     = "${azurerm_public_ip.vm05.domain_name_label}.${azurerm_public_ip.vm05.location}.cloudapp.azure.com"
#      type     = "ssh"
#      user     = "aleks"
#      password = var.VM_ADMIN_PASSWORD
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }
#
#}

#resource "azurerm_network_interface_backend_address_pool_association" "vm00" {
#    network_interface_id    = azurerm_network_interface.vm00.id
#    ip_configuration_name   = "mainNicConfiguration"
#    backend_address_pool_id = azurerm_lb_backend_address_pool.lb00.id
#    depends_on = [
#        azurerm_virtual_machine.vm00,
#    ]
#}
#
#resource "azurerm_lb_backend_address_pool" "lb01" {
#  loadbalancer_id = azurerm_lb.lb00.id
#  name            = "BackEndAddressPool01"
#}
#
#resource "azurerm_network_interface_backend_address_pool_association" "vm01" {
#    network_interface_id    = azurerm_network_interface.vm01.id
#    ip_configuration_name   = "mainNicConfiguration"
#    backend_address_pool_id = azurerm_lb_backend_address_pool.lb01.id
#    depends_on = [
#        azurerm_virtual_machine.vm01,
#    ]
#}
