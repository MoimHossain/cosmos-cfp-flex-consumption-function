@description('Cosmos DB account name')
param accountName string

@description('Location for Cosmos DB account')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

@description('Database (SQL API) name')
param databaseName string

@description('Container name for change feed tests')
param containerName string

@description('Logical partition key path (e.g. /partitionKey)')
@minLength(2)
param partitionKeyPath string = '/pk'

@description('Throughput mode: autoscale or manual')
@allowed([
  'autoscale'
  'manual'
])
param throughputMode string = 'autoscale'

@description('Autoscale max RU (if autoscale)')
param autoscaleMaxThroughput int = 4000

@description('Manual throughput RU/s (if manual)')
param manualThroughput int = 400

@description('Whether to enable zone redundancy for the region (set false to avoid zonal capacity issues)')
param isZoneRedundant bool = false


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
        isZoneRedundant: isZoneRedundant
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableFreeTier: false
    publicNetworkAccess: 'Enabled'
    capabilities: [
      // SQL (Core) API - no extra capability needed; leaving placeholder for future (e.g., EnableServerless)
    ]
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  name: databaseName
  parent: cosmosAccount
  properties: {
    resource: {
      id: databaseName
    }
    options: union(
      (throughputMode == 'autoscale') ? { autoscaleSettings: { maxThroughput: autoscaleMaxThroughput } } : {},
      (throughputMode == 'manual') ? { throughput: manualThroughput } : {}
    )
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  name: containerName
  parent: sqlDatabase
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [ partitionKeyPath ]
        kind: 'Hash'
        version: 2
      }
    }
    options: {}
  }
}

@description('Cosmos DB account endpoint')
output endpoint string = cosmosAccount.properties.documentEndpoint

@description('Cosmos DB account resource id')
output id string = cosmosAccount.id

@description('Cosmos DB database name')
output databaseName string = databaseName

@description('Cosmos DB container name')
output containerName string = containerName
