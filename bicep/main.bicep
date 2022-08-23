targetScope = 'resourceGroup'

param ResourceLocation string = resourceGroup().location
param VMSize string = 'Standard_E8ds_v4'
param VMName string = toLower('KaliVM-${uniqueString(resourceGroup().id)}')
param Username string = 'azureuser'

@secure()
param UserPassword string

resource WAFVNet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'WAFVNet'
  location: ResourceLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'KaliSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'ApplicationGatewaySubnet'
        properties: {
          addressPrefix:'10.0.1.0/24'
        }
      }
      {
        name: 'WorkloadSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'containergroup'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
    ]
  }
  resource KaliSubnet 'subnets' existing = {
    name: 'KaliSubnet'
  }
  resource ApplicationGatewaySubnet 'subnets' existing = {
    name: 'ApplicationGatewaySubnet'
  }
  resource WorkloadSubnet 'subnets' existing = {
    name: 'WorkloadSubnet'
  }
}

resource KaliVMPublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'KaliVMPublicIP'
  location: ResourceLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource KaliVMNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'KaliVMNSG'
  location: ResourceLocation
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'RDP'
        properties: {
          priority: 800
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource KaliVMNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'KaliVMNIC'
  location: ResourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: WAFVNet::KaliSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: KaliVMPublicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: KaliVMNSG.id
    }
  }
}


resource KaliVM 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: VMName
  location: ResourceLocation
  properties: {
    hardwareProfile: {
      vmSize: VMSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'Debian'
        offer: 'debian-11'
        sku: '11'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: KaliVMNIC.id
        }
      ]
    }
    osProfile: {
      computerName: VMName
      adminUsername: Username
      adminPassword: UserPassword
      customData: loadFileAsBase64('cloud-init.txt')
    }
  }
}

resource JuiceShop 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'juiceshop'
  location: ResourceLocation
  properties: {
    containers: [
      {
        name: 'juiceshop'
        properties: {
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 3
            }
          }
          image: 'bkimminich/juice-shop'
          ports: [
            {
              port: 3000
              protocol: 'TCP'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    ipAddress: {
      type: 'Private'
      ports: [
        {
          port: 3000
          protocol: 'TCP'
        }
      ]
    }
    subnetIds: [
      {
        id: WAFVNet::WorkloadSubnet.id
        name: 'WorkloadSubnet'
      }
    ]
  }
}

resource AppGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'AppGatewayPublicIP'
  location: ResourceLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}


resource applicationGateway 'Microsoft.Network/applicationGateways@2022-01-01' = {
  name: 'juiceshop'
  location: ResourceLocation
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
     {
      name: 'appgatewayConfig'
      properties: {
       subnet: {
        id: WAFVNet::ApplicationGatewaySubnet.id
       } 
      }
     } 
    ]
    frontendIPConfigurations: [
      {
        name: 'appFrontIP'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: WAFVNet::ApplicationGatewaySubnet.id
          }
          publicIPAddress: {
            id: AppGatewayPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'HTTP'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'juiceshop'
        properties: {
          backendAddresses: [
            {
              ipAddress: JuiceShop.properties.ipAddress.ip
            }
          ]
        }
      }
    ]
  }
}
