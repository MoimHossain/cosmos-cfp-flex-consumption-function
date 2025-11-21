param planName string
param appName string
param location string = resourceGroup().location
param storageAccountName string
param deploymentStorageContainerName string
param tags object = {}
param functionAppRuntime string = 'node'
param functionAppRuntimeVersion string = '20'
param maximumInstanceCount int = 100
param applicationInsightsName string
param userAssignedIdentityName string
param cosmosAccountName string
param cosmosAccountEndpoint string
param cosmosDatabaseName string
param cosmosContainerName string
param cosmosLeaseContainerName string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

resource flexFuncPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userAssignedIdentityName
  location: location
  tags: tags
}

resource flexFuncApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: flexFuncPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storage.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: userAssignedIdentity.properties.clientId
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storage.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storage.properties.primaryEndpoints.queue
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: storage.properties.primaryEndpoints.table
        }
        {
          name: 'CosmosDBConnection__credential'
          value: 'managedidentity'
        }
        {
          name: 'CosmosDBConnection__clientId'
          value: userAssignedIdentity.properties.clientId
        }
        {
          name: 'CosmosDBConnection__accountEndpoint'
          value: cosmosAccountEndpoint
        }
        {
          name: 'CosmosDBConnection__databaseName'
          value: cosmosDatabaseName
        }
        {
          name: 'CosmosDBConnection__containerName'
          value: cosmosContainerName
        }
        {
          name: 'CosmosDBConnection__leaseContainerName'
          value: cosmosLeaseContainerName
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.ConnectionString
        }
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: 2048
        triggers: {
          http: {}
        }
      }
      runtime: { 
        name: functionAppRuntime
        version: functionAppRuntimeVersion
      }
    }
  }
}

var storageRoleDefinitions = [
  {
    id: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    suffix: 'blob'
  }
  {
    id: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
    suffix: 'queue'
  }
  {
    id: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
    suffix: 'table'
  }
]

// Allow access from system-assigned identity to storage account using role assignments
resource storageRoleAssignmentsSystem 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for role in storageRoleDefinitions: {
  name: guid(storage.id, role.id, flexFuncApp.name, 'sys')
  scope: storage
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: flexFuncApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Allow access from user-assigned identity to storage account using role assignments
resource storageRoleAssignmentsUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for role in storageRoleDefinitions: {
  name: guid(storage.id, role.id, userAssignedIdentity.name, 'uai')
  scope: storage
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

var cosmosDataContributorRoleDefinitionId = '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosRoleAssignmentSystem 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-03-15-preview' = {
  name: guid(cosmosAccount.id, flexFuncApp.id, cosmosDatabaseName, 'cosmos-data-contributor-sys')
  parent: cosmosAccount
  properties: {
    principalId: flexFuncApp.identity.principalId
    roleDefinitionId: cosmosDataContributorRoleDefinitionId
    scope: '${cosmosAccount.id}/dbs/${cosmosDatabaseName}'
  }
}

resource cosmosRoleAssignmentUser 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-03-15-preview' = {
  name: guid(cosmosAccount.id, userAssignedIdentity.id, cosmosDatabaseName, 'cosmos-data-contributor-uai')
  parent: cosmosAccount
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: cosmosDataContributorRoleDefinitionId
    scope: '${cosmosAccount.id}/dbs/${cosmosDatabaseName}'
  }
}

output systemAssignedPrincipalId string = flexFuncApp.identity.principalId
output userAssignedPrincipalId string = userAssignedIdentity.properties.principalId
output userAssignedClientId string = userAssignedIdentity.properties.clientId
output functionAppResourceId string = flexFuncApp.id
