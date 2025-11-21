targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string
@minLength(1)
param location string 
@minLength(1)
param functionAppRuntime string
@minLength(1)
param functionAppRuntimeVersion string
@minLength(1)
param resourceGroupName string
@minLength(1)
param functionPlanName string
@minLength(1)
param functionAppName string
@minLength(1)
param storageAccountName string
param userAssignedIdentityName string = ''
param cosmosAccountName string = ''
@minLength(1)
param cosmosDatabaseName string = 'buutdb'
@minLength(1)
param cosmosContainerName string = 'jardocuments'
@minLength(1)
param cosmosLeaseContainerName string = 'jarevents'

@minValue(40)
@maxValue(1000)
param maximumInstanceCount int = 100
param uniqueGuid string = newGuid()
param shortGuid string = substring(uniqueGuid, 0, 3)
var abbrs = loadJsonContent('./abbreviations.json')
// Generate a unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Generate a unique function app name if one is not provided.
var appName = !empty(functionAppName) ? functionAppName : '${shortGuid}${abbrs.webSitesFunctions}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(toLower(appName), 32)}-${take(resourceToken, 7)}'
var userAssignedIdentityFinalName = !empty(userAssignedIdentityName) ? userAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
var cosmosAccountBaseName = !empty(cosmosAccountName) ? toLower(cosmosAccountName) : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
var cosmosAccountFinalName = take(replace(cosmosAccountBaseName, '-', ''), 44)
// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}


resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  location: location
  tags: tags
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
}


// Backing storage for Azure Functions
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    containers: [{name: deploymentStorageContainerName}]
  }
}

module monitoring 'core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.monitorLogAnalytics}${resourceToken}'
    applicationInsightsName: '${abbrs.monitorApplicationInsights}${resourceToken}'
  }
}

module cosmos 'core/cosmos/account.bicep' = {
  name: 'cosmos'
  scope: rg
  params: {
    accountName: cosmosAccountFinalName
    location: location
    tags: tags
    databaseName: cosmosDatabaseName
    containerName: cosmosContainerName
    leaseContainerName: cosmosLeaseContainerName
    partitionKeyPath: '/userid'
  }
}

// Azure Functions Flex Consumption
module flexFunction 'core/host/function.bicep' = {
  name: 'functionapp'
  scope: rg
  params: {
    location: location
    tags: tags
    planName: !empty(functionPlanName) ? functionPlanName : '${abbrs.webServerFarms}${resourceToken}${shortGuid}'
    appName: appName
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    applicationInsightsName : monitoring.outputs.applicationInsightsName
    functionAppRuntime: functionAppRuntime
    functionAppRuntimeVersion: functionAppRuntimeVersion
    maximumInstanceCount: maximumInstanceCount
    userAssignedIdentityName: userAssignedIdentityFinalName
    cosmosAccountName: cosmos.outputs.accountName
    cosmosAccountEndpoint: cosmos.outputs.documentEndpoint
    cosmosDatabaseName: cosmos.outputs.databaseName
    cosmosContainerName: cosmos.outputs.containerName
    cosmosLeaseContainerName: cosmos.outputs.leaseContainerName
  }
}
