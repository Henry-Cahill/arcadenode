#===============================================================================
#  ArcadeNode - Comprehensive Deployment Script (PowerShell)
#===============================================================================
#  This script handles all deployment tasks for the ArcadeNode Game Server Panel
#  including building, deploying, and managing the entire infrastructure.
#===============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet(
        "build-games", "build-panel", "build-all",
        "deploy", "stop", "restart", "status", "logs",
        "deploy-remote", "sync", "rebuild-remote", "remote-status", "remote-logs",
        "deploy-game", "list-games", "load-images",
        "backup", "cleanup", "update", "help", "menu"
    )]
    [string]$Command = "menu",
    
    [string]$Service,
    [string]$RemoteHost,
    [string]$RemoteUser,
    [string]$RemotePath = "~/ArcadeNode"
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$GameServersDir = Join-Path $ProjectRoot "game-servers"
$PanelDir = $ProjectRoot
$ConfigFile = Join-Path $ProjectRoot ".deploy-config.json"

# Colors
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info { Write-ColorOutput "[INFO] $args" "Cyan" }
function Write-Success { Write-ColorOutput "[SUCCESS] $args" "Green" }
function Write-Warning { Write-ColorOutput "[WARNING] $args" "Yellow" }
function Write-Error { Write-ColorOutput "[ERROR] $args" "Red" }

function Write-Banner {
    Clear-Host
    Write-Host @"
=====================================================================
                         ARCADE NODE
              Comprehensive Deployment System v1.0.0
=====================================================================
"@ -ForegroundColor Magenta
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Never hardcode the SA password - read it from the environment or the gitignored .env
function Get-SaPassword {
    if ($env:MSSQL_SA_PASSWORD) { return $env:MSSQL_SA_PASSWORD }

    $envFile = Join-Path $ProjectRoot ".env"
    if (Test-Path $envFile) {
        $line = Select-String -Path $envFile -Pattern '^\s*MSSQL_SA_PASSWORD\s*=' | Select-Object -First 1
        if ($line) { return ($line.Line -replace '^\s*MSSQL_SA_PASSWORD\s*=', '').Trim().Trim('"', "'") }
    }

    throw "MSSQL_SA_PASSWORD is not set. Export it or add it to $envFile (see .env.example)."
}

function Test-Docker {
    try {
        $null = docker info 2>$null
        Write-Success "Docker is available"
        return $true
    } catch {
        Write-Error "Docker is not running"
        return $false
    }
}

#===============================================================================
#  BUILD FUNCTIONS
#===============================================================================

function Build-GameServers {
    Write-Section "Building Game Server Images"
    
    $games = @("minecraft", "minecraft-bedrock", "project-zomboid", "arma-reforger")
    $built = 0
    $failed = 0
    
    foreach ($game in $games) {
        $gameDir = Join-Path $GameServersDir $game
        $dockerfile = Join-Path $gameDir "Dockerfile"
        
        if (Test-Path $dockerfile) {
            Write-Info "Building $game..."
            try {
                docker build -t "arcadenode/${game}:latest" $gameDir
                Write-Success "Built arcadenode/${game}:latest"
                $built++
            } catch {
                Write-Error "Failed to build $game"
                $failed++
            }
        } else {
            Write-Warning "Dockerfile not found for $game"
            $failed++
        }
    }
    
    Write-Host ""
    Write-Info "Build Summary: $built succeeded, $failed failed"
}

function Load-ImagesToNode {
    param([string]$NodeContainer = "arcadenode_node")
    
    Write-Section "Loading Game Server Images into Docker Node"
    
    $games = @("minecraft", "minecraft-bedrock", "project-zomboid", "arma-reforger")
    $loaded = 0
    $failed = 0
    
    # Check if node container is running
    $nodeRunning = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $NodeContainer }
    if (-not $nodeRunning) {
        Write-Error "Docker node container '$NodeContainer' is not running"
        Write-Info "Make sure the panel is deployed first with 'docker compose up -d'"
        return
    }
    
    Write-Info "Node container found: $NodeContainer"
    
    foreach ($game in $games) {
        $image = "arcadenode/${game}:latest"
        
        # Check if image exists locally
        $imageExists = docker image inspect $image 2>$null
        if (-not $imageExists) {
            Write-Warning "Image $image not found locally, building..."
            $gameDir = Join-Path $GameServersDir $game
            $dockerfile = Join-Path $gameDir "Dockerfile"
            
            if (Test-Path $dockerfile) {
                try {
                    docker build -t $image $gameDir
                } catch {
                    Write-Error "Failed to build $image"
                    $failed++
                    continue
                }
            } else {
                Write-Error "Dockerfile not found: $dockerfile"
                $failed++
                continue
            }
        }
        
        Write-Info "Loading $image into node..."
        
        try {
            # Save image to tar and pipe to docker load inside the node
            docker save $image | docker exec -i $NodeContainer docker load
            Write-Success "Loaded $image into node"
            $loaded++
        } catch {
            Write-Error "Failed to load $image into node"
            $failed++
        }
    }
    
    Write-Host ""
    Write-Info "Load Summary: $loaded succeeded, $failed failed"
    
    # Show images in node
    Write-Host ""
    Write-Info "Images available in node:"
    docker exec $NodeContainer docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

function Build-Panel {
    Write-Section "Building ArcadeNode Panel"
    
    Push-Location $PanelDir
    try {
        Write-Info "Building backend..."
        docker compose build backend
        Write-Success "Backend built successfully"
        
        Write-Info "Building frontend..."
        docker compose build frontend
        Write-Success "Frontend built successfully"
        
        Write-Success "Panel build complete!"
    } finally {
        Pop-Location
    }
}

function Build-All {
    Write-Section "Building All Components"
    Build-GameServers
    Build-Panel
    Write-Success "All builds complete!"
}

#===============================================================================
#  LOCAL DEPLOYMENT FUNCTIONS
#===============================================================================

function Deploy-Local {
    Write-Section "Deploying ArcadeNode Locally"
    
    Push-Location $PanelDir
    try {
        Write-Info "Starting services..."
        docker compose up -d
        
        Write-Info "Waiting for services to be ready..."
        Start-Sleep -Seconds 15
        
        # Wait for Docker-in-Docker node to be ready
        Write-Info "Waiting for Docker node to be ready..."
        $nodeReady = $false
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $null = docker exec arcadenode_node docker info 2>$null
                $nodeReady = $true
                break
            } catch {
                Start-Sleep -Seconds 2
            }
        }
        
        if ($nodeReady) {
            Write-Success "Docker node is ready"
            # Load game server images into the node
            Load-ImagesToNode -NodeContainer "arcadenode_node"
        } else {
            Write-Warning "Docker node may not be ready, skipping image loading"
            Write-Info "You can manually load images later with: .\deploy.ps1 load-images"
        }
        
        Write-Success "ArcadeNode deployed successfully!"
        Write-Host ""
        Write-ColorOutput "Access Points:" "White"
        Write-ColorOutput "  Frontend: http://localhost:3000" "Cyan"
        Write-ColorOutput "  Backend API: http://localhost:5000" "Cyan"
        Write-ColorOutput "  Swagger: http://localhost:5000/swagger" "Cyan"
    } finally {
        Pop-Location
    }
}

function Stop-Local {
    Write-Section "Stopping ArcadeNode"
    Push-Location $PanelDir
    try {
        docker compose down
        Write-Success "ArcadeNode stopped"
    } finally {
        Pop-Location
    }
}

function Restart-Local {
    Write-Section "Restarting ArcadeNode"
    Push-Location $PanelDir
    try {
        docker compose restart
        Write-Success "ArcadeNode restarted"
    } finally {
        Pop-Location
    }
}

function Show-LocalStatus {
    Write-Section "ArcadeNode Status"
    Push-Location $PanelDir
    try {
        docker compose ps
    } finally {
        Pop-Location
    }
}

function Show-Logs {
    param([string]$ServiceName)
    
    Push-Location $PanelDir
    try {
        if ($ServiceName) {
            docker compose logs -f $ServiceName
        } else {
            docker compose logs -f
        }
    } finally {
        Pop-Location
    }
}

#===============================================================================
#  REMOTE DEPLOYMENT FUNCTIONS
#===============================================================================

function Get-RemoteConfig {
    if (Test-Path $ConfigFile) {
        return Get-Content $ConfigFile | ConvertFrom-Json
    }
    return @{ Host = ""; User = ""; Path = "~/ArcadeNode" }
}

function Save-RemoteConfig {
    param($Config)
    $Config | ConvertTo-Json | Set-Content $ConfigFile
}

function Configure-Remote {
    Write-Section "Configure Remote Deployment"
    
    $config = Get-RemoteConfig
    
    Write-ColorOutput "Current Configuration:" "White"
    Write-Host "  Host: $($config.Host)"
    Write-Host "  User: $($config.User)"
    Write-Host "  Path: $($config.Path)"
    Write-Host ""
    
    $host = Read-Host "Enter remote host (IP or hostname)"
    $user = Read-Host "Enter remote user"
    $path = Read-Host "Enter remote path [$($config.Path)]"
    
    if (-not $path) { $path = $config.Path }
    
    $newConfig = @{
        Host = $host
        User = $user
        Path = $path
    }
    
    Save-RemoteConfig $newConfig
    Write-Success "Configuration saved"
}

function Sync-ToRemote {
    Write-Section "Syncing Files to Remote Server"
    
    $config = Get-RemoteConfig
    
    if (-not $config.Host -or -not $config.User) {
        Write-Error "Remote configuration not set. Run 'configure remote' first."
        return
    }
    
    $remote = "$($config.User)@$($config.Host)"
    $remotePath = $config.Path
    
    Write-Info "Creating remote directories..."
    ssh $remote "mkdir -p $remotePath/{backend/ServerPanel.API/{Controllers,DTOs,Services,Models,Data,Middleware},frontend/src/{pages/admin,components,services,types,stores,lib},game-servers/{minecraft,minecraft-bedrock,project-zomboid,arma-reforger}}"
    
    # Clean nested ServerPanel.API directories from previous deploys
    Write-Info "Cleaning stale nested directories on remote..."
    ssh $remote "rm -rf $remotePath/backend/ServerPanel.API/ServerPanel.API $remotePath/backend/ServerPanel.API/bin $remotePath/backend/ServerPanel.API/obj"
    
    Write-Info "Syncing files..."
    
    # Sync backend - use recursive scp for directories
    Write-Info "Syncing backend..."
    scp -r "$PanelDir\backend\ServerPanel.API\Controllers" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp -r "$PanelDir\backend\ServerPanel.API\DTOs" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp -r "$PanelDir\backend\ServerPanel.API\Services" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp -r "$PanelDir\backend\ServerPanel.API\Models" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp -r "$PanelDir\backend\ServerPanel.API\Data" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp -r "$PanelDir\backend\ServerPanel.API\Middleware" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp "$PanelDir\backend\ServerPanel.API\*.cs" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp "$PanelDir\backend\ServerPanel.API\*.csproj" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp "$PanelDir\backend\ServerPanel.API\*.json" "${remote}:${remotePath}/backend/ServerPanel.API/"
    scp "$PanelDir\backend\Dockerfile" "${remote}:${remotePath}/backend/"
    scp "$PanelDir\backend\.dockerignore" "${remote}:${remotePath}/backend/"
    
    # Sync frontend
    Write-Info "Syncing frontend..."
    scp -r "$PanelDir\frontend\src" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\*.json" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\*.js" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\*.ts" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\*.html" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\*.conf" "${remote}:${remotePath}/frontend/"
    scp "$PanelDir\frontend\Dockerfile" "${remote}:${remotePath}/frontend/"
    
    # Sync game-servers
    Write-Info "Syncing game-servers..."
    scp -r "$PanelDir\game-servers\*" "${remote}:${remotePath}/game-servers/"
    
    # Sync root files
    Write-Info "Syncing root files..."
    scp "$PanelDir\docker-compose.yml" "${remote}:${remotePath}/"
    
    Write-Success "Files synced successfully!"
}

function Deploy-Remote {
    Write-Section "Deploying to Remote Server"
    
    $config = Get-RemoteConfig
    
    if (-not $config.Host -or -not $config.User) {
        Write-Error "Remote configuration not set. Run 'configure remote' first."
        return
    }
    
    Sync-ToRemote
    
    $remote = "$($config.User)@$($config.Host)"
    $remotePath = $config.Path
    
    Write-Info "Building and starting services on remote..."
    ssh $remote "cd $remotePath && docker compose build --no-cache && docker compose up -d"
    
    Write-Info "Waiting for services to start..."
    Start-Sleep -Seconds 10
    
    Write-Info "Checking service status..."
    ssh $remote "cd $remotePath && docker compose ps"
    
    Write-Host ""
    Write-Success "Remote deployment complete!"
    Write-Host ""
    Write-ColorOutput "Access Points:" "White"
    Write-ColorOutput "  Frontend: http://$($config.Host):3000" "Cyan"
    Write-ColorOutput "  Backend API: http://$($config.Host):5000" "Cyan"
}

function Rebuild-RemoteService {
    param([string]$ServiceName)
    
    Write-Section "Rebuilding Remote Service: $ServiceName"
    
    $config = Get-RemoteConfig
    
    if (-not $config.Host -or -not $config.User) {
        Write-Error "Remote configuration not set. Run 'configure remote' first."
        return
    }
    
    $remote = "$($config.User)@$($config.Host)"
    $remotePath = $config.Path
    
    # First sync files
    Sync-ToRemote
    
    # Get the actual container name (usually prefixed with project name)
    Write-Info "Finding container for service: $ServiceName..."
    $containerName = ssh $remote "docker ps -a --filter 'name=$ServiceName' --format '{{.Names}}' | head -1"
    
    if (-not $containerName) {
        Write-Warning "Container not found, will create new one"
        $containerName = "arcadenode_$ServiceName"
    }
    
    Write-Info "Container name: $containerName"
    
    # Stop and remove existing container to avoid conflicts
    Write-Info "Stopping and removing existing container..."
    ssh $remote "docker stop $containerName 2>/dev/null; docker rm $containerName 2>/dev/null"
    
    # Rebuild the image
    Write-Info "Building $ServiceName image..."
    ssh $remote "cd $remotePath && docker compose build $ServiceName"
    
    # Get the network name (handle the double prefix issue)
    Write-Info "Finding network..."
    $networkName = ssh $remote "docker network ls --filter 'name=arcadenode' --format '{{.Name}}' | grep -v '^panel' | head -1"
    
    if (-not $networkName) {
        $networkName = "arcadenode_arcadenode_network"
    }
    
    Write-Info "Using network: $networkName"
    
    # Service-specific configuration
    switch ($ServiceName) {
        "backend" {
            Write-Info "Starting backend service..."
            $dbPassword = Get-SaPassword
            ssh $remote "docker run -d --name $containerName --network=$networkName -p 5000:8080 -e 'ConnectionStrings__DefaultConnection=Server=arcadenode_sqlserver;Database=PanelDB;User=sa;Password=$dbPassword;TrustServerCertificate=True' -e 'Docker__NodeUrl=tcp://arcadenode_node:2375' panel-backend:latest"
            
            # Restart frontend to refresh DNS resolution for backend hostname
            Write-Info "Restarting frontend to refresh DNS resolution..."
            ssh $remote "docker restart arcadenode_frontend 2>/dev/null || true"
        }
        "frontend" {
            Write-Info "Starting frontend service..."
            ssh $remote "docker run -d --name $containerName --network=$networkName -p 3000:80 panel-frontend:latest"
        }
        default {
            Write-Info "Starting service using docker compose..."
            ssh $remote "cd $remotePath && docker compose up -d --no-deps $ServiceName"
        }
    }
    
    Write-Info "Waiting for service to start..."
    Start-Sleep -Seconds 5
    
    # Check status
    Write-Info "Checking service status..."
    ssh $remote "docker ps --filter 'name=$containerName'"
    
    # Also show frontend status if backend was rebuilt
    if ($ServiceName -eq "backend") {
        Write-Info "Frontend status (restarted for DNS refresh):"
        ssh $remote "docker ps --filter 'name=arcadenode_frontend'"
    }
    
    # Check logs
    Write-Info "Recent logs:"
    ssh $remote "docker logs --tail=20 $containerName 2>&1"
    
    Write-Success "Service $ServiceName rebuilt and restarted!"
}

function Show-RemoteStatus {
    $config = Get-RemoteConfig
    
    if (-not $config.Host -or -not $config.User) {
        Write-Error "Remote configuration not set."
        return
    }
    
    Write-Section "Remote Server Status"
    ssh "$($config.User)@$($config.Host)" "cd $($config.Path) && docker compose ps"
}

function Show-RemoteLogs {
    param([string]$ServiceName)
    
    $config = Get-RemoteConfig
    
    if (-not $config.Host -or -not $config.User) {
        Write-Error "Remote configuration not set."
        return
    }
    
    $remote = "$($config.User)@$($config.Host)"
    
    if ($ServiceName) {
        ssh $remote "cd $($config.Path) && docker compose logs --tail=50 $ServiceName"
    } else {
        ssh $remote "cd $($config.Path) && docker compose logs --tail=50"
    }
}

#===============================================================================
#  GAME SERVER MANAGEMENT
#===============================================================================

function Deploy-GameServer {
    Write-Section "Deploy Game Server"
    
    Write-Host "Available game servers:"
    Write-Host "  1) Minecraft Java Edition"
    Write-Host "  2) Minecraft Bedrock Edition"
    Write-Host "  3) Project Zomboid"
    Write-Host "  4) Arma Reforger"
    Write-Host ""
    
    $choice = Read-Host "Select game (1-4)"
    
    $game = ""
    $ports = ""
    
    switch ($choice) {
        "1" { $game = "minecraft"; $ports = "-p 25565:25565 -p 25575:25575" }
        "2" { $game = "minecraft-bedrock"; $ports = "-p 19132:19132/udp -p 19133:19133/udp" }
        "3" { $game = "project-zomboid"; $ports = "-p 16261:16261/udp -p 16262:16262/udp -p 27015:27015" }
        "4" { $game = "arma-reforger"; $ports = "-p 2001:2001/udp -p 17777:17777/udp" }
        default { Write-Error "Invalid choice"; return }
    }
    
    $serverName = Read-Host "Enter server name"
    $memory = Read-Host "Enter memory limit (e.g., 2G)"
    if (-not $memory) { $memory = "2G" }
    
    $containerName = $serverName -replace " ", "_"
    
    Write-Info "Starting $game server: $serverName..."
    
    $cmd = "docker run -d --name `"$containerName`" --memory=`"$memory`" $ports --restart unless-stopped arcadenode/${game}:latest"
    Invoke-Expression $cmd
    
    Write-Success "Game server deployed: $containerName"
    docker ps --filter "name=$containerName"
}

function Show-GameServers {
    Write-Section "Running Game Servers"
    docker ps --filter "ancestor=arcadenode/minecraft:latest" `
              --filter "ancestor=arcadenode/minecraft-bedrock:latest" `
              --filter "ancestor=arcadenode/project-zomboid:latest" `
              --filter "ancestor=arcadenode/arma-reforger:latest" `
              --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

#===============================================================================
#  DATABASE MANAGEMENT
#===============================================================================

function Backup-Database {
    Write-Section "Database Backup"
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "arcadenode_backup_$timestamp.bak"
    
    Write-Info "Creating database backup..."
    
    docker exec arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd `
        -S localhost -U sa -P (Get-SaPassword) -C `
        -Q "BACKUP DATABASE ArcadeNode TO DISK='/var/opt/mssql/backup/$backupFile'"
    
    docker cp "arcadenode_sqlserver:/var/opt/mssql/backup/$backupFile" "./$backupFile"
    
    Write-Success "Backup created: $backupFile"
}

#===============================================================================
#  MAINTENANCE
#===============================================================================

function Invoke-Cleanup {
    Write-Section "Docker Cleanup"
    
    Write-Info "Removing stopped containers..."
    docker container prune -f
    
    Write-Info "Removing unused images..."
    docker image prune -f
    
    Write-Info "Removing unused volumes..."
    docker volume prune -f
    
    Write-Info "Removing unused networks..."
    docker network prune -f
    
    Write-Success "Cleanup complete"
    
    Write-Host ""
    docker system df
}

function Update-All {
    Write-Section "Update All Components"
    
    Write-Info "Pulling latest base images..."
    docker pull mcr.microsoft.com/mssql/server:2025-latest
    docker pull mcr.microsoft.com/dotnet/sdk:9.0
    docker pull mcr.microsoft.com/dotnet/aspnet:9.0
    docker pull node:20-alpine
    docker pull nginx:alpine
    docker pull docker:dind
    
    Write-Info "Rebuilding all images..."
    Build-All
    
    Write-Success "Update complete"
}

#===============================================================================
#  INTERACTIVE MENU
#===============================================================================

function Show-Menu {
    Write-Host ""
    Write-ColorOutput "=======================================================================" "White"
    Write-ColorOutput "                        MAIN MENU                                     " "White"
    Write-ColorOutput "=======================================================================" "White"
    Write-Host ""
    Write-ColorOutput "  BUILD" "Cyan"
    Write-Host "    1)  Build Game Server Images"
    Write-Host "    2)  Build Panel (Backend + Frontend)"
    Write-Host "    3)  Build All"
    Write-Host ""
    Write-ColorOutput "  LOCAL DEPLOYMENT" "Cyan"
    Write-Host "    4)  Deploy Locally"
    Write-Host "    5)  Stop Local Services"
    Write-Host "    6)  Restart Local Services"
    Write-Host "    7)  Show Local Status"
    Write-Host "    8)  View Logs"
    Write-Host ""
    Write-ColorOutput "  REMOTE DEPLOYMENT" "Cyan"
    Write-Host "    9)  Configure Remote Server"
    Write-Host "    10) Deploy to Remote Server"
    Write-Host "    11) Sync Files to Remote"
    Write-Host "    12) Rebuild Remote Service (backend/frontend)"
    Write-Host "    13) Remote Status"
    Write-Host "    14) Remote Logs"
    Write-Host ""
    Write-ColorOutput "  GAME SERVERS" "Cyan"
    Write-Host "    15) Deploy Game Server"
    Write-Host "    16) List Game Servers"
    Write-Host "    17) Load Images to Node"
    Write-Host ""
    Write-ColorOutput "  DATABASE" "Cyan"
    Write-Host "    18) Backup Database"
    Write-Host ""
    Write-ColorOutput "  MAINTENANCE" "Cyan"
    Write-Host "    19) Docker Cleanup"
    Write-Host "    20) Update All"
    Write-Host ""
    Write-Host "    0)  Exit"
    Write-Host ""
    Write-ColorOutput "=======================================================================" "White"
}

function Show-Help {
    Write-Host @"
ArcadeNode Deployment Script

Usage: .\deploy.ps1 [command] [-Service <name>]

Commands:
  build-games      Build game server Docker images
  build-panel      Build ArcadeNode panel
  build-all        Build everything
  deploy           Deploy locally
  stop             Stop local services
  restart          Restart local services
  status           Show local status
  logs             View logs (use -Service for specific service)
  deploy-remote    Deploy to remote server
  sync             Sync files to remote
  rebuild-remote   Rebuild and restart a specific remote service (use -Service)
  remote-status    Show remote status
  remote-logs      View remote logs
  deploy-game      Deploy a game server
  list-games       List running game servers
  load-images      Load game server images into Docker node
  backup           Backup database
  cleanup          Docker cleanup
  update           Update all components
  menu             Show interactive menu (default)

Examples:
  .\deploy.ps1 deploy
  .\deploy.ps1 logs -Service backend
  .\deploy.ps1 rebuild-remote -Service backend
  .\deploy.ps1 load-images
  .\deploy.ps1 sync
  .\deploy.ps1 build-all
"@
}

#===============================================================================
#  MAIN
#===============================================================================

# Check Docker only for local operations
$localCommands = @("build-games", "build-panel", "build-all", "deploy", "stop", "restart", "status", "logs", "deploy-game", "list-games", "load-images", "backup", "cleanup", "update")
if ($Command -in $localCommands -or $Command -eq "menu") {
    if (-not (Test-Docker)) {
        if ($Command -ne "menu") {
            exit 1
        }
    }
}

# Handle command
switch ($Command) {
    "build-games"    { Build-GameServers }
    "build-panel"    { Build-Panel }
    "build-all"      { Build-All }
    "deploy"         { Deploy-Local }
    "stop"           { Stop-Local }
    "restart"        { Restart-Local }
    "status"         { Show-LocalStatus }
    "logs"           { Show-Logs -ServiceName $Service }
    "deploy-remote"  { Deploy-Remote }
    "sync"           { Sync-ToRemote }
    "rebuild-remote" { 
        if (-not $Service) {
            $Service = Read-Host "Enter service name (backend, frontend, node, sqlserver)"
        }
        Rebuild-RemoteService -ServiceName $Service 
    }
    "remote-status"  { Show-RemoteStatus }
    "remote-logs"    { Show-RemoteLogs -ServiceName $Service }
    "deploy-game"    { Deploy-GameServer }
    "list-games"     { Show-GameServers }
    "load-images"    { Load-ImagesToNode -NodeContainer "arcadenode_node" }
    "backup"         { Backup-Database }
    "cleanup"        { Invoke-Cleanup }
    "update"         { Update-All }
    "help"           { Show-Help }
    "menu" {
        Write-Banner
        
        while ($true) {
            Show-Menu
            $choice = Read-Host "Select option"
            
            switch ($choice) {
                "1"  { Build-GameServers }
                "2"  { Build-Panel }
                "3"  { Build-All }
                "4"  { Deploy-Local }
                "5"  { Stop-Local }
                "6"  { Restart-Local }
                "7"  { Show-LocalStatus }
                "8"  { $svc = Read-Host "Service (blank for all)"; Show-Logs -ServiceName $svc }
                "9"  { Configure-Remote }
                "10" { Deploy-Remote }
                "11" { Sync-ToRemote }
                "12" { $svc = Read-Host "Service (backend, frontend)"; Rebuild-RemoteService -ServiceName $svc }
                "13" { Show-RemoteStatus }
                "14" { $svc = Read-Host "Service (blank for all)"; Show-RemoteLogs -ServiceName $svc }
                "15" { Deploy-GameServer }
                "16" { Show-GameServers }
                "17" { Load-ImagesToNode -NodeContainer "arcadenode_node" }
                "18" { Backup-Database }
                "19" { Invoke-Cleanup }
                "20" { Update-All }
                "0"  { Write-Host "Goodbye!"; exit 0 }
                default { Write-Error "Invalid option" }
            }
            
            Write-Host ""
            Read-Host "Press Enter to continue..."
        }
    }
}
