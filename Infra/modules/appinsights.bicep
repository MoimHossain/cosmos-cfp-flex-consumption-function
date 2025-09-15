@description('Application Insights name')
param appInsightsName string

@description('Location for Application Insights')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${appInsightsName}-laws'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

@description('The instrumentation key for Application Insights')
output instrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The connection string for Application Insights')
output connectionString string = applicationInsights.properties.ConnectionString

@description('The resource ID of Application Insights')
output id string = applicationInsights.id

@description('The name of Application Insights')
output name string = applicationInsights.name