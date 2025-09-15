param(
  [string]$ResourceGroupName = 'rgpcosmostriggercdp2025',
  [string]$FunctionAppName = 'func-cosmoscfp-dev-vyey4w',
  [string]$CosmosAccountName = 'coscosmoscfpdevvyey4w'
)

Write-Host "== Function Code Deployment ==" -ForegroundColor Cyan
Write-Host "RG: $ResourceGroupName" -ForegroundColor Gray
Write-Host "Function App: $FunctionAppName" -ForegroundColor Gray
Write-Host "Cosmos Account: $CosmosAccountName" -ForegroundColor Gray

function Fail($msg){ Write-Error $msg; exit 1 }

Write-Host "Fetching Cosmos DB primary key..." -ForegroundColor Yellow
$cosmosKey = az cosmosdb keys list -n $CosmosAccountName -g $ResourceGroupName --type keys --query primaryMasterKey -o tsv 2>$null
if(-not $cosmosKey){ Fail "Could not retrieve Cosmos key. Verify account name." }

$connectionString = "AccountEndpoint=https://$CosmosAccountName.documents.azure.com:443/;AccountKey=$cosmosKey;"
Write-Host "Setting app settings (connection string + names)..." -ForegroundColor Yellow
az functionapp config appsettings set -g $ResourceGroupName -n $FunctionAppName --settings `
  CosmosDbConnectionString="$connectionString" `
  DatabaseName=dbcosmoscfp `
  ContainerName=items `
  LeaseContainerName=leases 1>$null || Fail "Failed to set app settings"

Write-Host "Ensuring build artifact (artifact.zip) exists..." -ForegroundColor Yellow
$repoRoot = (Resolve-Path "$PSScriptRoot/.." ).Path
Set-Location $repoRoot
if(-not (Test-Path publish)){
  Write-Host "Running dotnet publish..." -ForegroundColor Yellow
  dotnet publish ./dotnet/CosmosDbChangeFeedFunction.csproj -c Release -o ./publish || Fail "dotnet publish failed"
}
if(Test-Path artifact.zip){ Remove-Item artifact.zip -Force }
Compress-Archive -Path publish/* -DestinationPath artifact.zip -Force || Fail "Failed to create artifact.zip"

Write-Host "Pushing zip via config-zip..." -ForegroundColor Yellow
az functionapp deployment source config-zip -g $ResourceGroupName -n $FunctionAppName --src artifact.zip || Fail "Zip deployment failed"

Write-Host "Listing deployed functions:" -ForegroundColor Yellow
az functionapp function list -g $ResourceGroupName -n $FunctionAppName --query "[].name" -o tsv || Fail "Failed to list functions"

Write-Host "Deployment complete." -ForegroundColor Green