using './main.bicep'

param projectName = 'cosmoscfp'
param environmentName = 'dev'
param location = 'East US'
param tags = {
  Environment: 'Development'
  Project: 'Cosmos Change Feed Processor'
  Purpose: 'Demo'
}