# Azure Function Infrastructure with Flex Consumption

This folder contains Bicep templates to deploy an Azure Function with Flex Consumption SKU and all required dependencies for a Cosmos DB change feed processing demo.

## Architecture

The infrastructure includes:

- **Azure Function App** with Flex Consumption SKU
- **App Service Plan** with Flex Consumption tier
- **Storage Account** for Azure Functions runtime requirements
- **Application Insights** with Log Analytics workspace for monitoring and telemetry

## Structure

```
Infra/
├── main.bicep              # Main deployment template
├── main.bicepparam         # Parameter file with default values
├── modules/
│   ├── storage.bicep       # Storage account module
│   ├── appinsights.bicep   # Application Insights module
│   ├── appserviceplan.bicep # App Service Plan module (Flex Consumption)
│   └── function.bicep      # Azure Function module
├── deploy.ps1              # PowerShell deployment script
└── README.md               # This file
```

## Deployment

### Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI installed
- Appropriate Azure subscription permissions

### Quick Deployment

1. **Using Azure CLI:**
```bash
# Login to Azure
az login

# Create resource group (optional)
az group create --name rg-cosmoscfp-dev --location "East US"

# Deploy using parameter file
az deployment group create \
  --resource-group rg-cosmoscfp-dev \
  --template-file main.bicep \
  --parameters main.bicepparam
```

2. **Using PowerShell Script:**
```powershell
./deploy.ps1 -ResourceGroupName "rg-cosmoscfp-dev" -Location "East US"
```

### Custom Parameters

You can override parameters directly:

```bash
az deployment group create \
  --resource-group rg-cosmoscfp-dev \
  --template-file main.bicep \
  --parameters projectName=myproject environmentName=test location="West US 2"
```

## Resources Created

After successful deployment, you'll have:

1. **App Service Plan** (`asp-{projectName}-{environment}-{unique}`)
   - Flex Consumption SKU (FC1)
   - Linux-based hosting

2. **Function App** (`func-{projectName}-{environment}-{unique}`)
   - .NET 8 Isolated runtime
   - Configured for Azure Functions v4
   - Linked to the Flex Consumption App Service Plan

3. **Storage Account** (`st{projectName}{environment}{unique}`)
   - Standard LRS
   - Secure configuration (HTTPS only, no public blob access)

4. **Application Insights** (`ai-{projectName}-{environment}-{unique}`)
   - Connected to Log Analytics workspace
   - 30-day retention

## Configuration for Cosmos DB

After deployment, add these application settings to your Function App for Cosmos DB change feed processing:

```json
{
  "CosmosDBConnection": "AccountEndpoint=https://{your-cosmos-account}.documents.azure.com:443/;AccountKey={your-key};"
}
```

## Notes

- Resource names include a unique suffix to avoid naming conflicts
- All resources are tagged for easy identification and cost tracking
- The configuration is optimized for demo/development use, not production
- Flex Consumption SKU provides automatic scaling and pay-per-execution billing