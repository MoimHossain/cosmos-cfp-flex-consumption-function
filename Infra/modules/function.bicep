@description('Function App name')
param functionAppName string

@description('Location for the Function App')
param location string = resourceGroup().location

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Storage account connection string (injected as app setting). Avoid passing raw secrets between modules when possible.')
param storageConnectionString string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Cosmos DB account endpoint (optional)')
param cosmosAccountEndpoint string = ''

@description('Cosmos DB database name (optional)')
param cosmosDatabaseName string = ''

@description('Cosmos DB container name (optional)')
param cosmosContainerName string = ''

@description('Cosmos DB lease container name (optional, for change feed)')
param cosmosLeaseContainerName string = 'leases'


@description('Tags to apply to resources')
param tags object = {}

var baseAppSettings = [
  {
    name: 'AzureWebJobsStorage'
    value: storageConnectionString
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
]

var cosmosSettings = concat(
  empty(cosmosAccountEndpoint) ? [] : [
    {
      name: 'COSMOS_ACCOUNT_ENDPOINT'
      value: cosmosAccountEndpoint
    }
  ],
  empty(cosmosDatabaseName) ? [] : [
    {
      name: 'COSMOS_DATABASE_NAME'
      value: cosmosDatabaseName
    }
  ],
  empty(cosmosContainerName) ? [] : [
    {
      name: 'COSMOS_CONTAINER_NAME'
      value: cosmosContainerName
    }
  ],
  empty(cosmosLeaseContainerName) ? [] : [
    {
      name: 'LeaseContainerName'
      value: cosmosLeaseContainerName
    }
  ],
  empty(cosmosDatabaseName) ? [] : [
    {
      name: 'DatabaseName'
      value: cosmosDatabaseName
    }
  ],
  empty(cosmosContainerName) ? [] : [
    {
      name: 'ContainerName'
      value: cosmosContainerName
    }
  ],
  []
)

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlanId
    // Removed one-deploy storage hosting block to allow classic zip deployment
    functionAppConfig: {
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    siteConfig: {
      appSettings: concat(baseAppSettings, cosmosSettings)
    }
  }
}

@description('The name of the Function App')
output name string = functionApp.name

@description('The resource ID of the Function App')
output id string = functionApp.id

@description('The default hostname of the Function App')
output defaultHostName string = functionApp.properties.defaultHostName
