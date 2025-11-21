param accountName string
param location string = resourceGroup().location
param tags object = {}
param databaseName string
param containerName string
param leaseContainerName string
param partitionKeyPath string = '/id'
param leasePartitionKeyPath string = '/id'
param databaseThroughput int = 400
param analyticalStorageEnabled bool = false

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    publicNetworkAccess: 'Enabled'
    disableKeyBasedMetadataWriteAccess: true
    disableLocalAuth: true
    enableAnalyticalStorage: analyticalStorageEnabled
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    }
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: databaseName
  parent: cosmosAccount
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: databaseThroughput
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: containerName
  parent: sqlDatabase
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [partitionKeyPath]
        kind: 'Hash'
      }
      defaultTtl: -1
    }
    options: {}
  }
}

resource leaseContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: leaseContainerName
  parent: sqlDatabase
  properties: {
    resource: {
      id: leaseContainerName
      partitionKey: {
        paths: [leasePartitionKeyPath]
        kind: 'Hash'
      }
      defaultTtl: -1
    }
    options: {}
  }
}

output accountName string = cosmosAccount.name
output accountResourceId string = cosmosAccount.id
output documentEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = databaseName
output containerName string = containerName
output leaseContainerName string = leaseContainerName
