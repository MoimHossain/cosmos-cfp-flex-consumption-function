# Realtime Event Visualization Web App

An ASP.NET Core 8 minimal web app that receives published events via a REST endpoint and broadcasts them to all connected browsers using Azure SignalR. The UI (single page) updates a live table in realtime.

## Features
- `POST /api/publishEvents` accepts JSON body: `{ id, transaction, account, amount }`.
- Broadcasts each accepted event to all clients over Azure SignalR hub at `/hub/notifications`.
- Stylish TailwindCSS UI (`/`) auto-appends new rows with a highlight effect.
- Health probe: `GET /health` -> `{ status: "ok" }`.
- Containerized (multi-stage .NET 8 build) listening on port `8080` in container.

## Environment Variables
| Name | Required | Purpose |
|------|----------|---------|
| `AZURE_SIGNALR_CONNECTION_STRING` | yes | Azure SignalR Service connection string (Access key based) |
| `ASPNETCORE_ENVIRONMENT` | no | Usual ASP.NET environment switch |

## Local Run (no Docker)
```powershell
cd visualization/webapp
$env:AZURE_SIGNALR_CONNECTION_STRING = "Endpoint=...;AccessKey=...;Version=1.0;"
dotnet run
# App listening on http://localhost:5000 (Kestrel default) or shown in console
```
Open `http://localhost:5000` (or the shown URL). The hub path is `/hub/notifications`.

## Test the API
```powershell
$body = @{ id = [guid]::NewGuid().ToString(); transaction = 'pass'; account = 'xxxx'; amount = 10.05 } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:5000/api/publishEvents -Method Post -ContentType 'application/json' -Body $body
```
The event should appear immediately in the grid.

## Docker Build & Run
```powershell
cd visualization/webapp
$env:AZURE_SIGNALR_CONNECTION_STRING = "Endpoint=...;AccessKey=...;Version=1.0;"
docker build -t realtime-visualization:latest .
# Run passing the connection string
docker run -e AZURE_SIGNALR_CONNECTION_STRING=$env:AZURE_SIGNALR_CONNECTION_STRING -p 8080:8080 realtime-visualization:latest
```
Browse to `http://localhost:8080`.

## POST Example (Docker port)
```powershell
$body = @{ id = [guid]::NewGuid().ToString(); transaction = 'pass'; account = 'acct1'; amount = 99.75 } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/api/publishEvents -Method Post -ContentType 'application/json' -Body $body
```

## Notes
- CORS is open (`AllowAnyOrigin`) for simplicity. Restrict to specific origins for production.
- Connection resilience: client auto-reconnects and updates connection state banner.
- JSON casing is camelCase.
- Consider adding authentication / API key if exposing publicly.

## Next Ideas
- Persist recent events (e.g., Redis / Cosmos DB) so late joiners see history.
- Add filtering & search in UI.
- Add metrics endpoint & instrumentation.
