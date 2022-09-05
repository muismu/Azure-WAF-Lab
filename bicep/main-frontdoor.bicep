targetScope = 'resourceGroup'

param ResourceLocation string = resourceGroup().location
param VMSize string = 'Standard_B2s'
param Username string = 'azureuser'
param LBName string = toLower('Juiceshop-${uniqueString(resourceGroup().id)}')

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
        name: 'JuiceshopSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          natGateway: {
            id: JuiceShopNATGateway.id
          }
        }
      }
      {
        name: 'LoadBalancerSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'PrivateLinkServiceSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  resource JuiceshopSubnet 'subnets' existing = {
    name: 'JuiceshopSubnet'
  }
  resource LoadBalancerSubnet 'subnets' existing = {
    name: 'LoadBalancerSubnet'
  }
  resource PrivateLinkServiceSubnet 'subnets' existing = {
    name: 'PrivateLinkServiceSubnet'
  }
}

resource NATPublicIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: toLower('juiceshop-nat-${uniqueString(resourceGroup().id)}')
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

resource JuiceShopNATGateway 'Microsoft.Network/natGateways@2022-01-01' = {
  name: toLower('juiceshop-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: NATPublicIP.id
      }
    ]
  }
}

resource JuiceshopVMNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: toLower('KaliNSG-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation
  properties: {
    securityRules: [
      {
        name: 'HTTP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'HTTP3000'
        properties: {
          priority: 800
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3000'
        }
      }
    ]
  }
}

resource JuiceVMNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: toLower('JuiceVMNIC-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: WAFVNet::JuiceshopSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', LBName, 'juiceshopbackend')
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: JuiceshopVMNSG.id
    }
  }
  dependsOn: [
    InternalLB
  ]
}

resource JuiceshopVM 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: toLower('Juiceshop-${uniqueString(resourceGroup().id)}')
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
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: JuiceVMNIC.id
        }
      ]
    }
    osProfile: {
      computerName: 'Juiceshop'
      adminUsername: Username
      adminPassword: UserPassword
      customData: loadFileAsBase64('owasp-docker-init.sh')
    }
  }
}

resource InternalLB 'Microsoft.Network/loadBalancers@2022-01-01' = {
  name: LBName
  location: ResourceLocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'juiceshop'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: WAFVNet::LoadBalancerSubnet.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'juiceshopbackend'
      }
    ]
    probes: [
      {
        name: 'juiceshop'
        properties: {
          port: 80
          protocol: 'Http'
          requestPath: '/'
          intervalInSeconds: 15
          numberOfProbes: 2 
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'juiceshop'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', LBName, 'juiceshop')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', LBName, 'juiceshopbackend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', LBName, 'juiceshop')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
        }
      }
    ]
  }
}

resource WAFPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: toLower('juiceshopwaf${uniqueString(resourceGroup().id)}')
  location: ResourceLocation
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.0'
          ruleSetAction: 'Block'
        }
      ]
    }
    policySettings: {
      mode: 'Prevention'
      enabledState: 'Enabled'
      requestBodyCheck: 'Enabled'
    }
  }
}

resource JuiceShopPrivateLinkService 'Microsoft.Network/privateLinkServices@2022-01-01' = {
  name: toLower('Juiceshop-${uniqueString(resourceGroup().id)}')
  location: ResourceLocation 
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', LBName, 'juiceshop')
      }
    ]
    ipConfigurations: [
      {
        name: 'juiceshop-ps'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: WAFVNet::PrivateLinkServiceSubnet.id
          }
          primary: false
        }
      }
    ]
    autoApproval: {
      subscriptions: [
        '*'
      ]
    }
  }
}

resource JuiceShopFrontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: 'juiceshop'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 20
  }
}

resource JuiceShopEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: 'juiceshop'
  parent: JuiceShopFrontDoor
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource JuiceShopOriginGroups 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: 'juiceshop'
  parent: JuiceShopFrontDoor
  properties: {
    loadBalancingSettings: {
     sampleSize: 4
     successfulSamplesRequired: 3 
    }
    healthProbeSettings: {
      probeIntervalInSeconds: 20
      probePath: '/'
      probeProtocol: 'Http'
      probeRequestType: 'GET'
    }
  }
}

resource JuiceShopOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: 'Juiceshop'
  parent: JuiceShopOriginGroups
  properties: {
    hostName: InternalLB.properties.frontendIPConfigurations[0].properties.privateIPAddress
    originHostHeader: InternalLB.properties.frontendIPConfigurations[0].properties.privateIPAddress
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    sharedPrivateLinkResource: {
      privateLink: {
        id: JuiceShopPrivateLinkService.id
      }
      privateLinkLocation: ResourceLocation
      requestMessage: 'juiceshop'
    }
  }
}

resource JuiceShopRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'juiceshop'
  parent: JuiceShopEndpoint
  dependsOn: [
    JuiceShopOrigin
  ]
  properties: {
    originGroup: {
      id: JuiceShopOriginGroups.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'
    enabledState: 'Enabled'
  }
}

resource JuiceShopSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2021-06-01' = {
  name: 'juiceshopsecurity'
  parent: JuiceShopFrontDoor
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
       id: WAFPolicy.id 
      }
      associations: [
       {
        domains: [
         {
          id: JuiceShopEndpoint.id
         } 
        ]
        patternsToMatch: [
          '/*'
        ]
       } 
      ]
    }
  }
}
