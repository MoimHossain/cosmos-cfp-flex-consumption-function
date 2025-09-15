@description('Storage account name')
param storageAccountName string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Storage account SKU')
param skuName string = 'Standard_LRS'

@description('Tags to apply to resources')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

@description('The primary connection string for the storage account')
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

@description('The name of the storage account')
output name string = storageAccount.name

@description('The resource ID of the storage account')
output id string = storageAccount.id