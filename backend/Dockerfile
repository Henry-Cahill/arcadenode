# .NET 9 Backend Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 5000

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["ServerPanel.API/ServerPanel.API.csproj", "ServerPanel.API/"]
RUN dotnet restore "ServerPanel.API/ServerPanel.API.csproj"
COPY . .
WORKDIR "/src/ServerPanel.API"
RUN dotnet build "ServerPanel.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "ServerPanel.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ServerPanel.API.dll"]
