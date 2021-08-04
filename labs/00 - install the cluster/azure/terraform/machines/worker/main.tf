variable "vm_id" {}
variable "rg_name" {}
variable "vnet" {}
variable "subnet" {}
variable "security_group" {}
variable "availability_set" {}
variable "pool" {}

resource "azurerm_public_ip" "worker" {
  name                = "worker-${var.vm_id}-pip"
  location            = "westeurope"
  resource_group_name = var.rg_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "worker" {
  name                 = "worker-${var.vm_id}-nic"
  location             = "westeurope"
  resource_group_name  = var.rg_name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "mainNicConfiguration"
    subnet_id                     = var.subnet
    private_ip_address_allocation = "static"
    private_ip_address            = "10.240.0.2${var.vm_id}"
    public_ip_address_id          = azurerm_public_ip.worker.id
  }
}

resource "azurerm_network_interface_security_group_association" "worker" {
  network_interface_id      = azurerm_network_interface.worker.id
  network_security_group_id = var.security_group
}

resource "azurerm_linux_virtual_machine" "worker" {
  name                  = "worker-${var.vm_id}"
  location              = "westeurope"
  resource_group_name   = var.rg_name
  network_interface_ids = [azurerm_network_interface.worker.id]
  size                  = "Standard_DS1_v2"
  availability_set_id   = var.availability_set

  os_disk {
    name                 = "worker-${var.vm_id}-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "18.04.202002180"
  }

  computer_name                   = "worker-${var.vm_id}"
  admin_username                  = "kuberoot"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "kuberoot"
    public_key = file("../../ssh-keys/id_rsa_local.pub")
  }

#  provisioner "remote-exec" {
#    connection {
#      host        = self.public_ip_address
#      user        = self.admin_username
#      private_key = "${file("../ssh-keys/id_rsa_local")}"
#    }
#
#    inline = [
#      "sudo apt -y update"
#    ]
#  }

  tags = {
    "pod-cidr" = "10.200.${var.vm_id}.0/24"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "worker" {
  network_interface_id    = azurerm_network_interface.worker.id
  ip_configuration_name   = "mainNicConfiguration"
  backend_address_pool_id = var.pool
}
