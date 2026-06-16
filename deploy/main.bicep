@description('Admin username for the VM')
param adminUsername string = 'azureadmin'

@description('Admin password for the VM')
@secure()
param adminPassword string = 'P@ssw0rd123456!'

@description('Location for all resources')
param location string = resourceGroup().location

@description('VM size - using B2ms (burstable) which has better availability for demos')
param vmSize string = 'Standard_B2ms'

var vmName = 'vm-contoso-university'
var nicName = '${vmName}-nic'
var publicIpName = '${vmName}-pip'
var nsgName = '${vmName}-nsg'
var vnetName = '${vmName}-vnet'
var subnetName = 'default'

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-rdp'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-http'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-https'
        properties: {
          priority: 1020
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'contosouni'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// Custom Script Extension to install IIS + SQL Server Express + .NET Framework 4.8
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm
  name: 'setup-iis-sql'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server,Web-Asp-Net45,Web-Net-Ext45,NET-Framework-45-ASPNET,Web-Mgmt-Tools -IncludeManagementTools; Set-ItemProperty -Path \'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\' -Name \'IE ESC\' -Value 0; Invoke-WebRequest -Uri \'https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us\' -OutFile \'C:\\SQLServer2022-SSEI-Expr.exe\'; Start-Process -FilePath \'C:\\SQLServer2022-SSEI-Expr.exe\' -ArgumentList \'/ACTION=Install\',\'/QUIET\',\'/IACCEPTSQLSERVERLICENSETERMS\',\'/FEATURES=SQLENGINE\',\'/INSTANCENAME=MSSQLSERVER\',\'/SECURITYMODE=SQL\',\'/SAPWD=P@ssw0rd123!\',\'/TCPENABLED=1\' -Wait -NoNewWindow; Invoke-WebRequest -Uri \'https://aka.ms/vs/17/release/vs_BuildTools.exe\' -OutFile \'C:\\vs_BuildTools.exe\'; Start-Process -FilePath \'C:\\vs_BuildTools.exe\' -ArgumentList \'--quiet\',\'--wait\',\'--add\',\'Microsoft.VisualStudio.Workload.WebBuildTools\',\'--add\',\'Microsoft.Net.Component.4.8.SDK\',\'--add\',\'Microsoft.Net.Component.4.8.TargetingPack\' -Wait -NoNewWindow; New-Item -ItemType Directory -Path \'C:\\inetpub\\wwwroot\\ContosoUniversity\' -Force"'
    }
  }
}

output vmPublicIp string = publicIp.properties.ipAddress
output vmName string = vm.name
output rdpAddress string = '${publicIp.properties.ipAddress}:3389'
