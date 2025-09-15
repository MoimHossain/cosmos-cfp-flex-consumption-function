param logAnalyticsName string
param applicationInsightsName string
param location string = resourceGroup().location
param tags object = {}


module loganalytics 'loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

module applicationInsights 'applicationinsights.bicep' = {
  name: 'applicationinsights'
  params: {
    name: applicationInsightsName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: loganalytics.outputs.id
  }
}

output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output applicationInsightsInstrumentationKey string = applicationInsights.outputs.instrumentationKey
output applicationInsightsName string = applicationInsights.outputs.name
output logAnalyticsWorkspaceId string = loganalytics.outputs.id
output logAnalyticsWorkspaceName string = loganalytics.outputs.name
