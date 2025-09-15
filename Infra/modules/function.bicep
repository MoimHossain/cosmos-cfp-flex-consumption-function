@description('Function App name')
param functionAppName string

@description('Location for the Function App')
param location string = resourceGroup().location

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Storage account connection string')
param storageConnectionString string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Tags to apply to resources')
param tags object = {}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlanId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: storageConnectionString
          authentication: {
            type: 'StorageAccountConnectionString'
          }
        }
      }
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
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
      ]
    }
  }
}

@description('The name of the Function App')
output name string = functionApp.name

@description('The resource ID of the Function App')
output id string = functionApp.id

@description('The default hostname of the Function App')
output defaultHostName string = functionApp.properties.defaultHostName