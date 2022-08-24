targetScope = 'resourceGroup'

param ResourceLocation string = resourceGroup().location

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
  resource ApplicationGatewaySubnet 'subnets' existing = {
    name: 'ApplicationGatewaySubnet'
  }
  resource WorkloadSubnet 'subnets' existing = {
    name: 'WorkloadSubnet'
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


resource applicationGateway 'Microsoft.Network/applicationGateways@2021-03-01' = {
  name: 'juiceshop'
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
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'juiceshop', 'appPublicFrontIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'juiceshop', 'HTTP')
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
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'juiceshop', 'juiceshop')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'juiceshop', 'juiceshop')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'juiceshop', 'juiceshop')
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
