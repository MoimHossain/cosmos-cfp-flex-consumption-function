#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys Azure Function infrastructure with Flex Consumption SKU

.DESCRIPTION
    This script deploys the Bicep templates for Azure Function with Flex Consumption
    and all required dependencies for Cosmos DB change feed processing.

.PARAMETER ResourceGroupName
    The name of the Azure resource group to deploy to

.PARAMETER Location
    The Azure region to deploy resources to (default: North Europe)

.PARAMETER ProjectName
    The name of the project for resource naming (default: cosmoscfp)

.PARAMETER EnvironmentName
    The environment name (dev, test, prod) (default: dev)

.EXAMPLE
    ./deploy.ps1 -ResourceGroupName "rgpcosmostriggercdp2025" -Location "North Europe"

.EXAMPLE
    ./deploy.ps1 -ResourceGroupName "rg-cosmoscfp-test" -Location "West US 2" -EnvironmentName "test"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "North Europe",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "cosmoscfp",
    
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "dev"
)

# Ensure we're in the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

Write-Host "🚀 Starting deployment of Azure Function infrastructure..." -ForegroundColor Green

# Check if resource group exists
Write-Host "📋 Checking resource group '$ResourceGroupName'..." -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName --query "name" -o tsv 2>$null

if (-not $rg) {
    Write-Host "📁 Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        exit 1
    }
}

# Deploy the Bicep template
Write-Host "🔧 Deploying Bicep template..." -ForegroundColor Yellow
$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "main.bicep" `
    --parameters projectName=$ProjectName environmentName=$EnvironmentName location=$Location `
    --query "properties.outputs" `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed"
    exit 1
}

# Parse outputs
$outputs = $deployment | ConvertFrom-Json

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "  Function App Name: $($outputs.functionAppName.value)" -ForegroundColor White
Write-Host "  Function App URL:  $($outputs.functionAppUrl.value)" -ForegroundColor White
Write-Host "  Storage Account:   $($outputs.storageAccountName.value)" -ForegroundColor White
Write-Host "  App Insights:      $($outputs.applicationInsightsName.value)" -ForegroundColor White
Write-Host "  App Service Plan:  $($outputs.appServicePlanName.value)" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure Cosmos DB connection string in Function App settings" -ForegroundColor White
Write-Host "  2. Deploy your function code to the Function App" -ForegroundColor White
Write-Host "  3. Test the change feed processing functionality" -ForegroundColor White
Write-Host ""