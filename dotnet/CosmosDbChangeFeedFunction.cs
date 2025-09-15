using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace CosmosDbChangeFeedFunction;

public class CosmosDbChangeFeedFunction
{
    private readonly ILogger<CosmosDbChangeFeedFunction> _logger;

    public CosmosDbChangeFeedFunction(ILogger<CosmosDbChangeFeedFunction> logger)
    {
        _logger = logger;
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
        if (input == null || input.Count == 0)
        {
            _logger.LogDebug("Change feed trigger invoked with no documents (heartbeat).");
            return;
        }

        _logger.LogInformation("Cosmos DB change feed triggered with {count} documents", input.Count);

        foreach (var document in input)
        {
            try
            {
                // Log the document (truncated if large)
                var documentJson = document.RootElement.GetRawText();
                var truncated = documentJson.Length > 2048 ? documentJson.Substring(0, 2048) + "...<truncated>" : documentJson;
                _logger.LogInformation("Processing document: {document}", truncated);

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

        // Simulate async processing work (replace with real logic)
        await Task.Yield();
        _logger.LogInformation("Document processing completed successfully");
    }
}