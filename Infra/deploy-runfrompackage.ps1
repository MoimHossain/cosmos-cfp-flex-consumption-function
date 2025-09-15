param(
  [string]$ResourceGroupName = 'rgpcosmostriggercdp2025',
  [string]$FunctionAppName = 'func-cosmoscfp-dev-vyey4w',
  [string]$StorageAccountName = 'stcosmoscfpdevvyey4w',
  [string]$CosmosAccountName = 'coscosmoscfpdevvyey4w',
  [string]$PackageBlobName = 'functionapp.zip',
  [int]$SasHours = 12
)

function Fail($m){ Write-Error $m; exit 1 }

Write-Host "== Run From Package Deployment ==" -ForegroundColor Cyan
Write-Host "RG: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Function App: $FunctionAppName" -ForegroundColor Gray
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Gray
Write-Host "Cosmos Account: $CosmosAccountName" -ForegroundColor Gray

$repoRoot = (Resolve-Path "$PSScriptRoot/.." ).Path
Set-Location $repoRoot

if(-not (Test-Path publish)){
  Write-Host "Building function (dotnet publish)..." -ForegroundColor Yellow
  dotnet publish ./dotnet/CosmosDbChangeFeedFunction.csproj -c Release -o ./publish || Fail "dotnet publish failed"
}
if(Test-Path artifact.zip){ Remove-Item artifact.zip -Force }
Compress-Archive -Path publish/* -DestinationPath artifact.zip -Force || Fail "Failed to create artifact.zip"

Write-Host "Ensuring container 'deploy' exists..." -ForegroundColor Yellow
$container='deploy'
az storage container create --account-name $StorageAccountName --name $container --auth-mode key 1>$null 2>$null

Write-Host "Uploading package blob ($PackageBlobName)..." -ForegroundColor Yellow
az storage blob upload --account-name $StorageAccountName --container-name $container --name $PackageBlobName --file artifact.zip --overwrite --auth-mode key 1>$null || Fail "Blob upload failed"

Write-Host "Generating SAS URL..." -ForegroundColor Yellow
$expiry = (Get-Date).ToUniversalTime().AddHours($SasHours).ToString('yyyy-MM-ddTHH:mmZ')
$sasToken = az storage blob generate-sas --account-name $StorageAccountName --container-name $container --name $PackageBlobName --permissions r --expiry $expiry -o tsv --auth-mode key
if(-not $sasToken){ Fail "Failed to generate SAS token" }
$packageUrl = "https://$StorageAccountName.blob.core.windows.net/$container/$PackageBlobName?$sasToken"
Write-Host "Package URL (SAS): $packageUrl" -ForegroundColor Gray

Write-Host "Fetching Cosmos primary key..." -ForegroundColor Yellow
$cosmosKey = az cosmosdb keys list -n $CosmosAccountName -g $ResourceGroupName --type keys --query primaryMasterKey -o tsv 2>$null
if(-not $cosmosKey){ Fail "Could not retrieve Cosmos DB key" }
$cosmosConn = "AccountEndpoint=https://$CosmosAccountName.documents.azure.com:443/;AccountKey=$cosmosKey;"

Write-Host "Setting app settings (run-from-package + cosmos)..." -ForegroundColor Yellow
az functionapp config appsettings set -g $ResourceGroupName -n $FunctionAppName --settings `
  WEBSITE_RUN_FROM_PACKAGE=$packageUrl `
  CosmosDbConnectionString="$cosmosConn" `
  DatabaseName=dbcosmoscfp `
  ContainerName=items `
  LeaseContainerName=leases 1>$null || Fail "Failed to set app settings"

Write-Host "Restarting function app..." -ForegroundColor Yellow
az functionapp restart -g $ResourceGroupName -n $FunctionAppName 1>$null || Fail "Restart failed"

Write-Host "Listing functions..." -ForegroundColor Yellow
az functionapp function list -g $ResourceGroupName -n $FunctionAppName --query "[].name" -o tsv || Fail "Failed to list functions"

Write-Host "Done." -ForegroundColor Green