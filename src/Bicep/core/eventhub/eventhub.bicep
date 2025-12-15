param namespaceName string
param eventHubName string
param location string = resourceGroup().location
param tags object = {}
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'
param skuCapacity int = 1
param isAutoInflateEnabled bool = false
@maxValue(20)
param maximumThroughputUnits int = 0
@minValue(1)
@maxValue(32)
param partitionCount int = 2
@minValue(1)
@maxValue(90)
param messageRetentionInDays int = 1
param sharedAccessPolicyName string = 'appclient'
param sharedAccessPolicyRights array = [
  'Manage'
  'Send'
  'Listen'
]

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-05-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
    capacity: skuCapacity
  }
  properties: {
    isAutoInflateEnabled: isAutoInflateEnabled
    maximumThroughputUnits: maximumThroughputUnits
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    kafkaEnabled: true
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-05-01-preview' = {
  name: eventHubName
  parent: eventHubNamespace
  properties: {
    messageRetentionInDays: messageRetentionInDays
    partitionCount: partitionCount
    status: 'Active'
  }
}

resource namespaceAuthRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-05-01-preview' = {
  name: sharedAccessPolicyName
  parent: eventHubNamespace
  properties: {
    rights: sharedAccessPolicyRights
  }
}

var namespaceAuthKeys = listKeys(namespaceAuthRule.id, '2024-05-01-preview')

output namespaceName string = eventHubNamespace.name
output namespaceResourceId string = eventHubNamespace.id
output namespaceFqdn string = '${eventHubNamespace.name}.servicebus.windows.net'
output eventHubName string = eventHub.name
output eventHubResourceId string = eventHub.id
output sharedAccessPolicyName string = namespaceAuthRule.name
output sharedAccessPrimaryConnectionString string = namespaceAuthKeys.primaryConnectionString
output sharedAccessSecondaryConnectionString string = namespaceAuthKeys.secondaryConnectionString
