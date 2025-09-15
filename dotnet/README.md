# Cosmos DB Change Feed Azure Function

This is a simple Azure Function sample that demonstrates how to listen to Cosmos DB container changes using the Cosmos DB trigger for Azure Functions.

## Features

- **Cosmos DB Change Feed Processing**: Automatically processes changes from a Cosmos DB container
- **Environment Variable Configuration**: All connection details are configurable via environment variables
- **Auto-create Lease Container**: The lease container is automatically created if it doesn't exist
- **Flexible and Simple**: Minimal code that can be easily extended for specific business logic

## Environment Variables

The function requires the following environment variables to be set:

| Variable | Description | Example |
|----------|-------------|---------|
| `CosmosDbConnectionString` | Cosmos DB connection string | `AccountEndpoint=https://your-account.documents.azure.com:443/;AccountKey=your-key;` |
| `DatabaseName` | Name of the Cosmos DB database | `SampleDB` |
| `ContainerName` | Name of the container to monitor for changes | `SampleContainer` |
| `LeaseContainerName` | Name of the lease container (will be created if not exists) | `leases` |

## Local Development

### Prerequisites

- .NET 8.0 SDK
- Azure Functions Core Tools (optional, for local debugging)
- Cosmos DB Emulator or Azure Cosmos DB account

### Configuration

1. Copy `local.settings.template.json` to `local.settings.json` and update it with your Cosmos DB configuration:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "CosmosDbConnectionString": "AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==",
    "DatabaseName": "SampleDB",
    "ContainerName": "SampleContainer",
    "LeaseContainerName": "leases"
  }
}
```

2. Make sure your Cosmos DB database and container exist. The function will automatically create the lease container.

### Running Locally

```bash
# Restore packages
dotnet restore

# Build the project
dotnet build

# Run the function
dotnet run
```

## How It Works

1. **Change Feed Trigger**: The function uses the `CosmosDBTrigger` attribute to automatically listen for changes in the specified Cosmos DB container.

2. **Lease Container**: Azure Functions uses a lease container to track the position in the change feed across multiple function instances. This ensures each change is processed exactly once.

3. **Environment Variables**: All configuration is read from environment variables, making it easy to deploy across different environments without code changes.

4. **Auto-creation**: The `CreateLeaseContainerIfNotExists = true` parameter ensures the lease container is automatically created.

5. **Error Handling**: Basic error handling is included with logging for troubleshooting.

## Extending the Function

To add your own business logic, modify the `ProcessDocumentAsync` method in `CosmosDbChangeFeedFunction.cs`. Common scenarios include:

- Sending notifications
- Updating other systems or databases
- Transforming and storing data elsewhere
- Triggering workflows or business processes
- Generating reports or analytics

## Deployment

### Azure Deployment

1. Create an Azure Function App with .NET 8.0 runtime
2. Set the environment variables in the Function App configuration
3. Deploy the code using your preferred method (Visual Studio, Azure CLI, GitHub Actions, etc.)

### Environment Variables in Azure

Set these in your Azure Function App Configuration:

- `CosmosDbConnectionString`: Your Azure Cosmos DB connection string
- `DatabaseName`: Your database name
- `ContainerName`: Your container name to monitor
- `LeaseContainerName`: Name for the lease container

## Important Notes

- The function will be triggered for **all changes** in the monitored container
- Make sure your function logic is idempotent in case of retries
- Monitor your function's performance and Cosmos DB RU consumption
- Consider implementing dead letter queues for failed processing scenarios
- The lease container will be created in the same database as the monitored container