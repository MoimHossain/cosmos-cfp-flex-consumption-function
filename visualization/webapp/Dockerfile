# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY WebApp.csproj ./
RUN dotnet restore WebApp.csproj
COPY . .
RUN dotnet publish WebApp.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080 \
    AZURE_SIGNALR_CONNECTION_STRING="" \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
COPY --from=build /app/publish ./
EXPOSE 8080
ENTRYPOINT ["dotnet", "WebApp.dll"]
