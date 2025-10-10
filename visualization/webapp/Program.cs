using Microsoft.AspNetCore.Http.Json;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Azure.SignalR;
using WebApp.Hubs;
using WebApp.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services
// Only use Azure SignalR if a valid connection string is provided; otherwise fall back to in-process SignalR.
var signalRBuilder = builder.Services.AddSignalR();
var signalRConn = Environment.GetEnvironmentVariable("AZURE_SIGNALR_CONNECTION_STRING");
var usingAzureSignalR = false;
if (!string.IsNullOrWhiteSpace(signalRConn))
{
    usingAzureSignalR = true;
    signalRBuilder.AddAzureSignalR(o => o.ConnectionString = signalRConn);
}

builder.Services.Configure<JsonOptions>(opts =>
{
    opts.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
});

builder.Services.AddCors(policy =>
{
    policy.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();
app.UseCors();
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapHub<NotificationHub>("/hub/notifications");

app.MapPost("/api/publishEvents", async (HttpContext ctx, IHubContext<NotificationHub> hub) =>
{
    try
    {
        var payload = await ctx.Request.ReadFromJsonAsync<IncomingPayload>();
        if (payload is null)
        {
            return Results.BadRequest(new { error = "Invalid or empty JSON body." });
        }
        // Basic validation
        if (string.IsNullOrWhiteSpace(payload.Id) || string.IsNullOrWhiteSpace(payload.Transaction) || string.IsNullOrWhiteSpace(payload.Account))
        {
            return Results.BadRequest(new { error = "Fields id, transaction, account are required." });
        }
        var evt = new EventNotification(payload.Id, payload.Transaction, payload.Account, payload.Amount, DateTimeOffset.UtcNow);
        await hub.Clients.All.SendAsync("eventNotification", evt);
        return Results.Accepted($"/api/publishEvents/{evt.Id}", evt);
    }
    catch (System.Text.Json.JsonException)
    {
        return Results.BadRequest(new { error = "Malformed JSON." });
    }
});

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapGet("/health/signalr", () =>
{
    return Results.Ok(new
    {
        mode = usingAzureSignalR ? "AzureSignalR" : "InProcess",
        azureConfigured = usingAzureSignalR,
        connStringPresent = !string.IsNullOrWhiteSpace(signalRConn),
        connStringLength = signalRConn?.Length ?? 0,
        envVarName = "AZURE_SIGNALR_CONNECTION_STRING"
    });
});

app.Run();

internal record IncomingPayload(string Id, string Transaction, string Account, decimal Amount);
