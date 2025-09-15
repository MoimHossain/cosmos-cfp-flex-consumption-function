param(
    [string]$ResourceGroup = 'rgpcosmostriggercdp2025',
    [string]$FunctionApp = 'func-cosmoscfp-dev-vyey4w',
    [string]$CosmosAccount = 'coscosmoscfpdevvyey4w',
    [string]$DatabaseName = 'dbcosmoscfp',
    [string]$ContainerName = 'items',
    [string]$LeaseContainerName = 'leases'
)

$ErrorActionPreference = 'Stop'
Write-Host "Building function project..."
$publishDir = Join-Path $PSScriptRoot '../dotnet/publish'
$zipPath = Join-Path $PSScriptRoot '../dotnet/publish.zip'
if(Test-Path $publishDir){ Remove-Item $publishDir -Recurse -Force }
& dotnet publish (Join-Path $PSScriptRoot '../dotnet/CosmosDbChangeFeedFunction.csproj') -c Release -o $publishDir | Out-Null
if(Test-Path $zipPath){ Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $publishDir '*') -DestinationPath $zipPath -Force

Write-Host "Retrieving Cosmos DB connection string..."
$cs = az cosmosdb keys list -n $CosmosAccount -g $ResourceGroup --type connection-strings --query "connectionStrings[0].connectionString" -o tsv

Write-Host "Updating app settings..."
az functionapp config appsettings set -g $ResourceGroup -n $FunctionApp --settings "CosmosDbConnectionString=$cs" "DatabaseName=$DatabaseName" "ContainerName=$ContainerName" "LeaseContainerName=$LeaseContainerName" | Out-Null

Write-Host "Deploying zip..."
az functionapp deployment source config-zip -g $ResourceGroup -n $FunctionApp --src $zipPath

Write-Host "Listing functions..."
az functionapp function list -g $ResourceGroup -n $FunctionApp -o table

Write-Host "Insert a sample document with partition key 'pk' to trigger change feed:" -ForegroundColor Yellow
Write-Host "az cosmosdb sql container create/update if needed; then: az cosmosdb sql container throughput show ... (optional)." -ForegroundColor DarkGray
Write-Host "To insert sample doc: az cosmosdb sql container create item is not a direct command; use Data Explorer or SDK. For quick test, use Azure Portal or a small script." -ForegroundColor DarkGray
