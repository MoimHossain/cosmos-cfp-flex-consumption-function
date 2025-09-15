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

// Deploy Function App module
module functionApp 'modules/function.bicep' = {
  name: 'function-deployment'
  params: {
    functionAppName: functionAppName
    location: location
    appServicePlanId: appServicePlan.outputs.id
    storageConnectionString: storageAccount.outputs.connectionString
    appInsightsConnectionString: applicationInsights.outputs.connectionString
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