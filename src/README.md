# Flex Consumption plan | Azure Functions custom handlers

## Create function app using bicep file

This bicep sample deploys a function app and other required resources in a Flex Consumption plan. When used in a Bicep-based deployment, this Bicep file creates these Azure components:

| Component | Description |
| ---- | ---- |
| **Function app** | This is the serverless Flex Consumption app where you can deploy your functions code. The function app is configured with Application Insights and Storage Account.|
| **Function app plan** | The Azure Functions app plan associated with your Flex Consumption app. For Flex Consumption there is only one app allowed per plan, but the plan is still created.|
| **Application Insights** | This is the telemetry service associated with the Flex Consumption app for you to monitor live applications, detect performance anomalies, review telemetry logs, and to understand your app behavior.|
| **Log Analytics Workspace** | This is the workspace used by Application Insights for the app telemetry.|
| **Storage Account** | This is the Microsoft Azure storage account that [Azure Functions requires](https://learn.microsoft.com/azure/azure-functions/storage-considerations) when you create a function app instance.|


### 1. Modify the parameters file

Create a copy and modify the parameters file `main.bicepparam` to specify the values for the parameters. The parameters file contains the following parameters that you must specify values for before you can deploy the app:

| Parameter | Description |
| ---- | ---- |
| **environmentName** | a unique name to be used for the resources being created.|
| **location** | the location where the assets will be created. You can find the supported regions with the `az functionapp list-flexconsumption-locations` command of the Azure CLI.|
| **functionAppRuntimeVersion** | the runtime version for the function app (for example, '1.0').|
| **resourceGroupName** | the name of the resource group to deploy resources into.|
| **functionPlanName** | the name of the function app plan.|
| **functionAppName** | the name of the function app.|
| **storageAccountName** | the name of the storage account.|

Here is an example `main.bicepparam` that you can modify:

```bicep
using 'main.bicep'
param environmentName = 'myflexconsumptionapp'
param location = 'eastasia'
param functionAppRuntimeVersion = '1.0'
param resourceGroupName = 'myResourceGroup'
param functionPlanName = 'myFunctionPlan'
param functionAppName = 'myFunctionApp'
param storageAccountName = 'mystorageacct'
```

### 2. Deploy the bicep file

You can deploy bicep file through one of the following methods
1. [Visual Studio Code with the Bicep extension](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-vscode)
2. [Azure CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-cli). Update to the latest Bicep CLI before using Azure CLI - `az bicep upgrade`
3. [PowerShell](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deploy-powershell)

If you created a `maincopy.bicepparam` file with the above parameter values, you can deploy the app by running the following command, making sure to modify the value for location with the same location as in your updated copy of `main.bicepparam`:

```
az deployment sub create --name deployment1 --location eastus --template-file main.bicep --parameters maincopy.bicepparam
```
## Build and Test the Sample App Locally

### Prerequisites
1. [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Cisolated-process%2Cnode-v4%2Cpython-v2%2Chttp-trigger%2Ccontainer-apps&pivots=programming-language-csharp)
2. [Go](https://go.dev/doc/install)
3. [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Build Steps

```
cd JarService
go build -o main .
func start
```
> Note: It is important to keep the output file name as main as it is configured in the function.json file

## Deploy function app to Azure

Currently there are two methods of deploying a function app with custom handlers app to flex Consumption plan

### 1. Azure functions Core tools

We need to build the Go file for Linux to ensure compatibility with the Flex Consumption plan.

```powershell
$env:GOOS = "linux"
$env:GOARCH = "amd64"

go build -o main .
func azure functionapp publish buutdemo-jar-service --resource-group buutdemo
```

### 2. Azure CLI

#### Windows
We need to use a special zip utility if we want to use Azure CLI from windows for deployment. This utility ensures that the executable files in the payload has the correct permissions for linux environment.

```powershell
$env:GOOS = "linux"
$env:GOARCH = "amd64"
cd GoCustomHandlers
go build -o main .
func azure functionapp publish buutdemo-jar-service --resource-group buutdemo
```

#### Linux

```Bash
go build -o main .
func azure functionapp publish buutdemo-jar-service --resource-group buutdemo
```
    

### Checking the cosmos DB feed

For all version and deletes (preview):

Change in host.json:

```
    "id": "Microsoft.Azure.Functions.ExtensionBundle.Preview",
    "version": "[4.0.0, 5.0.0)"
```
Change in function.json:

```
{
  "bindings": [
    {
      "type": "cosmosDBTrigger",
      "name": "inputDocuments",
      "direction": "in",
      "connection": "CosmosDBConnection",
      "databaseName": "buutdb",
      "containerName": "jardocuments",
      "leaseContainerName": "eventlistenerlease",
      "changeFeedMode": "AllVersionsAndDeletes",
      "createLeaseContainerIfNotExists": true,
      "leaseContainerPrefix": "demo",
      "maxItemsPerInvocation": 100,
      "feedPollDelay": 500
    }
  ]
}
```

without All version and delete:

Change in host.json:

```
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
```

Change in function.json:

```
{
  "bindings": [
    {
      "type": "cosmosDBTrigger",
      "name": "inputDocuments",
      "direction": "in",
      "connection": "CosmosDBConnection",
      "databaseName": "buutdb",
      "containerName": "jardocuments",
      "leaseContainerName": "latesteventlistenerlease",
      "createLeaseContainerIfNotExists": true,
      "leaseContainerPrefix": "demo",
      "maxItemsPerInvocation": 100,
      "feedPollDelay": 500
    }
  ]
}
```