targetScope = 'resourceGroup'

param ResourceLocation string = resourceGroup().location
param VMSize string = 'Standard_E8ds_v4'
param VMName string = toLower('KaliVM-${uniqueString(resourceGroup().id)}')
param Username string = 'azureuser'
param AppGatewayName string = toLower('AppGW-${uniqueString(resourceGroup().id)}')
param ApplicationName string = toLower('JuiceShop-${uniqueString(resourceGroup().id)}')

@secure()
param UserPassword string

resource WAFVNet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: toLower('VNet-${uniqueString(resourceGroup().id)}')
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
  name: toLower('KaliPublicIP-${uniqueString(resourceGroup().id)}')
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
  name: toLower('KaliNSG-${uniqueString(resourceGroup().id)}')
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
  name: toLower('KaliVMNIC-${uniqueString(resourceGroup().id)}')
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
  name: toLower('KaliVM-${uniqueString(resourceGroup().id)}')
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
  name: AppGatewayName
  location: ResourceLocation
  properties: {
    containers: [
      {
        name: 'juiceshop'
        properties: {
          resources: {
            requests: {
              cpu: 4
              memoryInGB: 8
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
  name: toLower('AppGWPublicIP-${uniqueString(resourceGroup().id)}')
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


resource WAFLogWorkSpace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: toLower('log-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation 
  properties: {
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    sku: {
      name: 'PerGB2018'
    }
    workspaceCapping: {
      dailyQuotaGb: 10
    }
  }
}

resource WAFWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(toLower('workbook-${uniqueString(resourceGroup().id)}'))
  location: ResourceLocation
  kind: 'shared'
  properties: {
    displayName: toLower('workbook-${uniqueString(resourceGroup().id)}')
    serializedData: string(loadJsonContent('workbook.json'))
    version: '1.0'
    sourceId: WAFLogWorkSpace.id
    category: 'workbook'
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2022-01-01' = {
  name: AppGatewayName
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
        name: 'appPublicFrontIP'
        properties: {
          publicIPAddress: {
            id: AppGatewayPublicIP.id
          }
        }
      }
      {
        name: 'appPrivateFrontIP'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.10'
          subnet: {
            id: WAFVNet::ApplicationGatewaySubnet.id
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
    backendHttpSettingsCollection: [
      {
        name: 'juiceshop'
        properties: {
          port: 3000
          protocol: 'Http'
        }
      }
    ]
    httpListeners: [
      {
        name: 'juiceshop'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', AppGatewayName, 'appPrivateFrontIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', AppGatewayName, 'HTTP')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'juiceshop'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', AppGatewayName, 'juiceshop')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', AppGatewayName, 'juiceshop')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', AppGatewayName, 'juiceshop')
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      ruleSetVersion: '3.0'
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
    }
  }
}

resource AppGWDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview'= {
  name: toLower('diagnostic-${uniqueString(resourceGroup().id)}')
  scope: applicationGateway
  properties: {
    workspaceId: WAFLogWorkSpace.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
    ]
  }
}
