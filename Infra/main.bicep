@description('The name of the project - used for naming resources')
param projectName string

@description('The environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Project: projectName
}

// Generate unique names for resources
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 6)
var storageAccountName = 'st${projectName}${environmentName}${uniqueSuffix}'
var functionAppName = 'func-${projectName}-${environmentName}-${uniqueSuffix}'
var appInsightsName = 'ai-${projectName}-${environmentName}-${uniqueSuffix}'
var appServicePlanName = 'asp-${projectName}-${environmentName}-${uniqueSuffix}'
var storageApiVersion = '2023-05-01'
// Cosmos DB account name must be 3-44 chars, lowercase, numbers only (no hyphens)
var cosmosAccountName = 'cos${projectName}${environmentName}${uniqueSuffix}'
var cosmosDatabaseName = 'db${projectName}'
var cosmosContainerName = 'items'

// Deploy storage account module
module storageAccount 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
  }
}

// Deploy Application Insights module
module applicationInsights 'modules/appinsights.bicep' = {
  name: 'appinsights-deployment'
  params: {
    appInsightsName: appInsightsName
    location: location
    tags: tags
  }
}

// Deploy App Service Plan module
module appServicePlan 'modules/appserviceplan.bicep' = {
  name: 'appserviceplan-deployment'
  params: {
    appServicePlanName: appServicePlanName
    location: location
    tags: tags
  }
}

// Deploy Cosmos DB (SQL API) account, database, container
module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos-deployment'
  params: {
    accountName: cosmosAccountName
    location: location
    tags: tags
    databaseName: cosmosDatabaseName
    containerName: cosmosContainerName
    isZoneRedundant: false
  }
}

// Deploy Function App module
module functionApp 'modules/function.bicep' = {
  name: 'function-deployment'
  dependsOn: [ storageAccount ]
  params: {
    functionAppName: functionAppName
    location: location
    appServicePlanId: appServicePlan.outputs.id
    // Construct connection string locally to avoid outputting secret from storage module
    storageConnectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), storageApiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    appInsightsConnectionString: applicationInsights.outputs.connectionString
    cosmosAccountEndpoint: cosmos.outputs.endpoint
    cosmosDatabaseName: cosmos.outputs.databaseName
    cosmosContainerName: cosmos.outputs.containerName
    cosmosLeaseContainerName: 'leases'
    tags: tags
  }
}

// Outputs
@description('The name of the deployed Function App')
output functionAppName string = functionApp.outputs.name

@description('The default hostname of the Function App')
output functionAppUrl string = 'https://${functionApp.outputs.defaultHostName}'

@description('The name of the storage account')
output storageAccountName string = storageAccount.outputs.name

@description('The name of Application Insights')
output applicationInsightsName string = applicationInsights.outputs.name

@description('The name of the App Service Plan')
output appServicePlanName string = appServicePlan.outputs.name

@description('Cosmos DB account name')
output cosmosAccountName string = cosmosAccountName
@description('Cosmos DB endpoint')
output cosmosEndpoint string = cosmos.outputs.endpoint
@description('Cosmos DB database name')
output cosmosDatabaseName string = cosmos.outputs.databaseName
@description('Cosmos DB container name')
output cosmosContainerName string = cosmos.outputs.containerName
