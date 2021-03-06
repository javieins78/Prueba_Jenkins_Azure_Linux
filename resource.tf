variable "prefix" {
  default = "santalucia"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "westeurope"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "main" {
  name                = "SantaluciaPIP"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  domain_name_label   = "santalucia-azurerm-resource"
}

resource "azurerm_network_interface" "main" {
  name                = "santalucia-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_security_group" "main" {
    name                = "myNetworkSecurityGroupWinRm"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.main.name
    
    security_rule {
        name                       = "WinRm"
        priority                   = 200
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "5985-5986"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
      security_rule {
        name                       = "Access-RDP"
        priority                   = 210
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
  
     security_rule {
        name                       = "Access-http"
        priority                   = 220
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
  
      security_rule {
        name                       = "InternetAccess"
        priority                   = 230
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

 data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "main" {
  name                = "keyvaultcertmain"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = "ece33831-9bc7-4217-a330-2082dfa1a525"

  sku_name = "standard"

  access_policy {
    tenant_id = "ece33831-9bc7-4217-a330-2082dfa1a525"
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "create",
      "delete",
      "deleteissuers",
      "get",
      "getissuers",
      "import",
      "list",
      "listissuers",
      "managecontacts",
      "manageissuers",
      "setissuers",
      "update",
    ]

    key_permissions = [
      "backup",
      "create",
      "decrypt",
      "delete",
      "encrypt",
      "get",
      "import",
      "list",
      "purge",
      "recover",
      "restore",
      "sign",
      "unwrapKey",
      "update",
      "verify",
      "wrapKey",
    ]

    secret_permissions = [
      "backup",
      "delete",
      "get",
      "list",
      "purge",
      "recover",
      "restore",
      "set",
    ]
  }
} 
  
 resource "azurerm_key_vault_certificate" "main" { 
   name      = "${var.prefix}-cert" 
   vault_uri = "azurerm_key_vault.main.vault_uri" 
  
   certificate_policy { 
     issuer_parameters { 
       name = "Self" 
     } 
  
     key_properties { 
       exportable = true 
       key_size   = 2048 
       key_type   = "RSA" 
       reuse_key  = true 
     } 
  
     lifetime_action { 
       action { 
         action_type = "AutoRenew" 
       } 
  
       trigger { 
         days_before_expiry = 30 
       } 
     } 
  
     secret_properties { 
       content_type = "application/x-pkcs12" 
     } 
  
     x509_certificate_properties { 
       key_usage = [ 
         "cRLSign", 
         "dataEncipherment", 
         "digitalSignature", 
         "keyAgreement", 
         "keyCertSign", 
         "keyEncipherment", 
       ] 
  
       subject            = "CN=${azurerm_network_interface.main.private_ip_address}" 
       validity_in_months = 12 
     } 
   } 
 } 
    

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_A2_v2"

 storage_os_disk {
    name            = "FromPackerImageOsDisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
}
storage_image_reference {
    id = "/subscriptions/2de9d718-d170-4e29-af3b-60c30e449b3c/resourceGroups/santalucia-imagenes-packer/providers/Microsoft.Compute/images/ws2016-winrm-packer"
}

# resource "azurerm_image" "main" {
#  name                = "packer-image"
#  location            = azurerm_resource_group.main.location
#  resource_group_name = azurerm_resource_group.main.name
    
# Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

# Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

#storage_image_reference {
#    publisher = "MicrosoftWindowsServer"
#    offer     = "WindowsServer"
#    sku       = "2016-Datacenter"
#    version   = "latest"
# }
#  storage_os_disk {
#    name              = "myosdisk1"
#    caching           = "ReadWrite"
#    create_option     = "FromImage"
#    managed_disk_type = "Standard_LRS"
#  }
  os_profile {
    computer_name  = "Prueba"
    admin_username = "arqsis"
    admin_password = "Password1234!"
  }
 

   os_profile_windows_config { 
     provision_vm_agent = true 
 
     winrm { 
       protocol        = "https" 
       certificate_url = "azurerm_key_vault_certificate.main.secret_id" 
     } 
   } 
  
   os_profile_secrets { 
     source_vault_id = "${azurerm_key_vault.main.id}" 
  
     vault_certificates { 
       certificate_url   = "${azurerm_key_vault_certificate.main.secret_id}" 
       certificate_store = "My" 
     } 
   } 
 } 
  
  # os_profile_windows_config {
 #   provision_vm_agent = "true"
 #   enable_automatic_upgrades = "true"
 #   winrm {
 #     protocol        = "http" 
 #     }
 # }
  
 # }
  
#resource "azurerm_virtual_machine_extension" "custom-script" {
#  name                 = "WinRm"
#  virtual_machine_id   = azurerm_virtual_machine.main.id
# publisher            = "Microsoft.Azure.Extensions"
#  type                 = "CustomScript"
#  type_handler_version = "2.0"

#  settings = <<SETTINGS
#    {
#        "fileUris": "https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.ps1",
#        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File install.ps1"
#     }
#  SETTINGS

#}
  
