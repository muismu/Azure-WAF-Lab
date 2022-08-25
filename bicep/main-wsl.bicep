targetScope = 'resourceGroup'

param ResourceLocation string = resourceGroup().location
param AppGWName string = toLower('Juiceshop-${uniqueString(resourceGroup().id)}')

resource WAFVNet 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: toLower('VNET-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'ApplicationGatewaySubnet'
        properties: {
          addressPrefix:'10.0.1.0/24'
        }
      }
    ]
  }
  resource ApplicationGatewaySubnet 'subnets' existing = {
    name: 'ApplicationGatewaySubnet'
  }
}

resource JuiceShop 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: toLower('Juiceshop-${uniqueString(resourceGroup().id)}')
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
      type: 'Public'
      ports: [
        {
          port: 3000
          protocol: 'TCP'
        }
      ]
    }
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

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-03-01' = {
  name: AppGWName
  location: ResourceLocation
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
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
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', AppGWName, 'appPublicFrontIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', AppGWName, 'HTTP')
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', AppGWName, 'juiceshop')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', AppGWName, 'juiceshop')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', AppGWName, 'juiceshop')
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
