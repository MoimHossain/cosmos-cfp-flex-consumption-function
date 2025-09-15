using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Cosmos;
using System.Text.Json;

namespace CosmosDbChangeFeedFunction;

public class CosmosDbChangeFeedFunction
{
    private readonly ILogger<CosmosDbChangeFeedFunction> _logger;
    private readonly CosmosClient _cosmosClient;

    public CosmosDbChangeFeedFunction(ILogger<CosmosDbChangeFeedFunction> logger)
    {
        _logger = logger;
        
        // Read connection string from environment variables
        var connectionString = Environment.GetEnvironmentVariable("CosmosDbConnectionString") 
            ?? throw new InvalidOperationException("CosmosDbConnectionString environment variable is required");
        
        _cosmosClient = new CosmosClient(connectionString);
    }

    [Function("ProcessCosmosDbChanges")]
    public async Task ProcessChangesAsync(
        [CosmosDBTrigger(
            databaseName: "%DatabaseName%",
            containerName: "%ContainerName%",
            Connection = "CosmosDbConnectionString",
            LeaseContainerName = "%LeaseContainerName%",
            CreateLeaseContainerIfNotExists = true)] IReadOnlyList<JsonDocument> input)
    {
        _logger.LogInformation("Cosmos DB change feed triggered with {count} documents", input.Count);

        foreach (var document in input)
        {
            try
            {
                // Log the document that was changed
                var documentJson = document.RootElement.GetRawText();
                _logger.LogInformation("Processing document: {document}", documentJson);

                // Here you can add your business logic to process the changed document
                // For example:
                // - Send notification
                // - Update other systems
                // - Transform and store data
                // - Trigger workflows

                await ProcessDocumentAsync(document);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing document");
                // Consider dead letter queue or retry logic based on your requirements
            }
        }
    }

    private async Task ProcessDocumentAsync(JsonDocument document)
    {
        // Example business logic - extract some properties and log them
        if (document.RootElement.TryGetProperty("id", out var idProperty))
        {
            var documentId = idProperty.GetString();
            _logger.LogInformation("Processing document with ID: {documentId}", documentId);
        }

        if (document.RootElement.TryGetProperty("_ts", out var timestampProperty))
        {
            var timestamp = timestampProperty.GetInt64();
            var dateTime = DateTimeOffset.FromUnixTimeSeconds(timestamp);
            _logger.LogInformation("Document was last modified at: {timestamp}", dateTime);
        }

        // Simulate some processing work
        await Task.Delay(100);
        
        _logger.LogInformation("Document processing completed successfully");
    }

    /// <summary>
    /// This method demonstrates how to ensure the lease container exists
    /// if you need more control over its creation
    /// </summary>
    private async Task EnsureLeaseContainerExistsAsync()
    {
        try
        {
            var databaseName = Environment.GetEnvironmentVariable("DatabaseName") 
                ?? throw new InvalidOperationException("DatabaseName environment variable is required");
            var leaseContainerName = Environment.GetEnvironmentVariable("LeaseContainerName") 
                ?? throw new InvalidOperationException("LeaseContainerName environment variable is required");

            var database = _cosmosClient.GetDatabase(databaseName);
            var leaseContainer = database.GetContainer(leaseContainerName);

            // Try to read the container to check if it exists
            await leaseContainer.ReadContainerAsync();
            _logger.LogInformation("Lease container {containerName} already exists", leaseContainerName);
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            // Container doesn't exist, create it
            var databaseName = Environment.GetEnvironmentVariable("DatabaseName")!;
            var leaseContainerName = Environment.GetEnvironmentVariable("LeaseContainerName")!;
            
            var database = _cosmosClient.GetDatabase(databaseName);
            await database.CreateContainerIfNotExistsAsync(leaseContainerName, "/id");
            _logger.LogInformation("Created lease container {containerName}", leaseContainerName);
        }
    }
}