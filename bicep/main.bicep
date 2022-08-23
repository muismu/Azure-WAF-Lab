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
        name: 'KaliSubnet'
        properties: {
          addressPrefixes: [
            '10.0.0.0/24'
          ]
        }
      }
      {
        name: 'ApplicationGatewaySubnet'
        properties: {
          addressPrefixes: [
            '10.0.1.0/24'
          ]
        }
      }
      {
        name: 'WorkloadSubnet'
        properties: {
          addressPrefixes: [
            '10.0.2.0/24'
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

resource KaliVM 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: 'KaliVM'
  location: ResourceLocation
  zones: [
    '1'
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_E8ds_v4'
    }
  }
}
