#===============================================================================
#  ArcadeNode - Quick Deploy Script (PowerShell)
#===============================================================================
#  Simplified deployment for rapid iteration during development.
#  Automatically handles syncing, building, and restarting containers.
#===============================================================================

param(
    [Parameter(Position=0)]
    [ValidateSet(
        "all", "backend", "frontend", "games", "pz", "minecraft",
        "sync", "rebuild", "restart", "logs", "status", "shell",
        "reset-db", "reset-password", "clean-containers",
        "setup-ssh-key", "loadimages", "help"
    )]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Target,
    
    [switch]$NoCache,
    [switch]$Follow
)

$ErrorActionPreference = "Stop"

#===============================================================================
#  CONFIGURATION - Override with ARCADENODE_* environment variables
#===============================================================================
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Config = @{
    RemoteHost = if ($env:ARCADENODE_HOST) { $env:ARCADENODE_HOST } else { "arcadenode.local" }
    RemoteUser = if ($env:ARCADENODE_USER) { $env:ARCADENODE_USER } else { "arcadenode" }
    RemotePath = if ($env:ARCADENODE_PATH) { $env:ARCADENODE_PATH } else { "~/panel" }
    LocalPath  = $ProjectRoot
}

#===============================================================================
#  HELPERS
#===============================================================================

function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

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

function Get-Remote { return "$($Config.RemoteUser)@$($Config.RemoteHost)" }

function Invoke-Remote {
    param([string]$Command, [switch]$Quiet)
    # -Quiet suppresses the echo for commands that embed a secret
    if (-not $Quiet) { Write-Host "  > $Command" -ForegroundColor DarkGray }
    ssh $(Get-Remote) $Command
}

function Invoke-RemoteMulti {
    param([string[]]$Commands)
    $joined = $Commands -join " && "
    Write-Host "  > [batch: $($Commands.Count) commands]" -ForegroundColor DarkGray
    ssh $(Get-Remote) $joined
}

function Copy-ToRemote {
    param([string]$LocalPath, [string]$RemotePath)
    $fullRemote = "$(Get-Remote):$($Config.RemotePath)/$RemotePath"
    Write-Host "  Copying: $LocalPath -> $RemotePath" -ForegroundColor DarkGray
    scp -r $LocalPath $fullRemote
}

function Copy-MultiToRemote {
    param([hashtable]$Files)  # @{ "local/path" = "remote/path" }
    
    # Create a temp script to do all copies
    $remote = Get-Remote
    $remotePath = $Config.RemotePath
    
    foreach ($local in $Files.Keys) {
        $remoteDir = $Files[$local]
        $fullRemote = "${remote}:${remotePath}/${remoteDir}"
        Write-Host "  $local -> $remoteDir" -ForegroundColor DarkGray
        scp -r $local $fullRemote
    }
}

#===============================================================================
#  SYNC FUNCTIONS - Use single SCP per component to minimize password prompts
#===============================================================================

function Ensure-RemoteDirectories {
    Write-Info "Ensuring remote directories exist and are clean..."
    Invoke-Remote "chmod -R u+rwx $($Config.RemotePath) 2>/dev/null || true"
    Invoke-Remote "rm -rf $($Config.RemotePath)/backend/ServerPanel.API $($Config.RemotePath)/frontend/src $($Config.RemotePath)/cartridges $($Config.RemotePath)/docs 2>/dev/null || true"
    Invoke-Remote "mkdir -p $($Config.RemotePath)/backend/ServerPanel.API/Controllers $($Config.RemotePath)/backend/ServerPanel.API/Models $($Config.RemotePath)/backend/ServerPanel.API/Services $($Config.RemotePath)/backend/ServerPanel.API/DTOs $($Config.RemotePath)/backend/ServerPanel.API/Data $($Config.RemotePath)/frontend/src/components/cartridges $($Config.RemotePath)/frontend/src/pages/admin $($Config.RemotePath)/frontend/src/services $($Config.RemotePath)/frontend/src/stores $($Config.RemotePath)/frontend/src/types $($Config.RemotePath)/frontend/src/lib $($Config.RemotePath)/cartridges/project-zomboid $($Config.RemotePath)/cartridges/minecraft-java $($Config.RemotePath)/docs $($Config.RemotePath)/game-servers"
    Invoke-Remote "chmod -R u+rwx $($Config.RemotePath)"
    Write-Success "Remote directories prepared"
}

function Sync-Backend {
    Write-Info "Syncing backend files..."
    
    $backendLocal = Join-Path $Config.LocalPath "backend"
    $remote = Get-Remote
    
    # Single SCP for entire backend directory
    Write-Host "  backend/ -> backend/" -ForegroundColor DarkGray
    scp -r "$backendLocal\ServerPanel.API" "$backendLocal\Dockerfile" "${remote}:$($Config.RemotePath)/backend/"
    
    Write-Success "Backend synced"
}

function Sync-Frontend {
    Write-Info "Syncing frontend files..."
    
    $frontendLocal = Join-Path $Config.LocalPath "frontend"
    $remote = Get-Remote
    
    # Single SCP for entire frontend directory
    Write-Host "  frontend/ -> frontend/" -ForegroundColor DarkGray
    scp -r "$frontendLocal\src" "$frontendLocal\package.json" "$frontendLocal\vite.config.ts" "$frontendLocal\tsconfig.json" "$frontendLocal\tsconfig.node.json" "$frontendLocal\tailwind.config.js" "$frontendLocal\postcss.config.js" "$frontendLocal\eslint.config.js" "$frontendLocal\index.html" "$frontendLocal\nginx.conf" "$frontendLocal\Dockerfile" "${remote}:$($Config.RemotePath)/frontend/"
    
    Write-Success "Frontend synced"
}

function Sync-GameServers {
    Write-Info "Syncing game server files..."
    
    $gamesLocal = Join-Path $Config.LocalPath "game-servers"
    $remote = Get-Remote
    
    # Single SCP for game-servers
    Write-Host "  game-servers/ -> game-servers/" -ForegroundColor DarkGray
    scp -r "$gamesLocal\*" "${remote}:$($Config.RemotePath)/game-servers/"
    
    Write-Success "Game servers synced"
}

function Sync-DockerCompose {
    Write-Info "Syncing docker-compose.yml..."
    $remote = Get-Remote
    scp (Join-Path $Config.LocalPath "docker-compose.yml") "${remote}:$($Config.RemotePath)/"
    Write-Success "Docker compose synced"
}

function Sync-Cartridges {
    Write-Info "Syncing cartridge definitions..."
    
    $cartridgesLocal = Join-Path $Config.LocalPath "cartridges"
    $remote = Get-Remote
    
    # Check if cartridges directory exists locally
    if (Test-Path $cartridgesLocal) {
        Write-Host "  cartridges/ -> cartridges/" -ForegroundColor DarkGray
        scp -r "$cartridgesLocal\*" "${remote}:$($Config.RemotePath)/cartridges/"
        Write-Success "Cartridges synced"
    } else {
        Write-Warn "No cartridges directory found, skipping..."
    }
}

function Sync-Docs {
    Write-Info "Syncing documentation..."
    
    $docsLocal = Join-Path $Config.LocalPath "docs"
    $remote = Get-Remote
    
    # Check if docs directory exists locally
    if (Test-Path $docsLocal) {
        Write-Host "  docs/ -> docs/" -ForegroundColor DarkGray
        scp -r "$docsLocal\*" "${remote}:$($Config.RemotePath)/docs/"
        Write-Success "Docs synced"
    } else {
        Write-Warn "No docs directory found, skipping..."
    }
}

function Sync-All {
    Write-Info "Syncing all files..."
    Ensure-RemoteDirectories
    Sync-Backend
    Sync-Frontend
    Sync-GameServers
    Sync-Cartridges
    Sync-Docs
    Sync-DockerCompose
}

#===============================================================================
#  BUILD & DEPLOY FUNCTIONS
#===============================================================================

function Remove-Container {
    param([string]$ContainerName)
    Write-Info "Removing container: $ContainerName"
    Invoke-Remote "docker stop $ContainerName 2>/dev/null || true; docker rm $ContainerName 2>/dev/null || true"
}

function Build-RemoteService {
    param([string]$Service, [bool]$NoCache = $false)
    
    $cacheFlag = if ($NoCache) { "--no-cache" } else { "" }
    
    Write-Info "Building $Service on remote..."
    Invoke-Remote "cd $($Config.RemotePath) && docker compose build $cacheFlag $Service"
    Write-Success "$Service built"
}

function Restart-RemoteService {
    param([string]$Service)
    
    Write-Info "Restarting $Service..."
    Invoke-Remote "cd $($Config.RemotePath) && docker compose up -d --force-recreate $Service"
    Write-Success "$Service restarted"
}

function Deploy-Backend {
    param([bool]$NoCache = $false)
    
    Write-Host "`n=== Deploying Backend ===" -ForegroundColor Magenta
    

    Sync-Backend
    Remove-Container "arcadenode_backend"
    Build-RemoteService "backend" $NoCache
    Restart-RemoteService "backend"
    
    Start-Sleep -Seconds 3
    Show-ServiceLogs "backend" 20
}

function Deploy-Frontend {
    param([bool]$NoCache = $false)
    
    Write-Host "`n=== Deploying Frontend ===" -ForegroundColor Magenta
    

    Sync-Frontend
    Remove-Container "arcadenode_frontend"
    Build-RemoteService "frontend" $NoCache
    Restart-RemoteService "frontend"
    
    Start-Sleep -Seconds 2
    Show-ServiceLogs "frontend" 10
}

function Deploy-All {
    param([bool]$NoCache = $false)
    
    Write-Host "`n=== Full Deployment ===" -ForegroundColor Magenta
    

    Sync-All
    
    # Clean up all arcadenode containers
    Write-Info "Cleaning up existing containers..."
    Invoke-Remote "docker ps -a --filter 'name=arcadenode' -q | xargs -r docker stop; docker ps -a --filter 'name=arcadenode' -q | xargs -r docker rm"
    
    # Build and start
    $cacheFlag = if ($NoCache) { "--no-cache" } else { "" }
    Write-Info "Building all services..."
    Invoke-Remote "cd $($Config.RemotePath) && docker compose build $cacheFlag"
    
    Write-Info "Starting all services..."
    Invoke-Remote "cd $($Config.RemotePath) && docker compose up -d"
    
    Start-Sleep -Seconds 5
    Show-Status
    
    Write-Host "`n" -NoNewline
    Write-Success "Deployment complete!"
    Write-Host "  Frontend: http://$($Config.RemoteHost):3000" -ForegroundColor Cyan
    Write-Host "  Backend:  http://$($Config.RemoteHost):5000" -ForegroundColor Cyan
    Write-Host "  Swagger:  http://$($Config.RemoteHost):5000/swagger" -ForegroundColor Cyan
}

#===============================================================================
#  GAME SERVER BUILD FUNCTIONS
#===============================================================================

function Build-ProjectZomboid {
    Write-Host "`n=== Building Project Zomboid ===" -ForegroundColor Magenta
    

    $pzLocal = Join-Path $Config.LocalPath "game-servers\project-zomboid"
    Copy-ToRemote "$pzLocal\*" "game-servers/project-zomboid/"
    
    Write-Info "Building Project Zomboid image..."
    Invoke-Remote "cd $($Config.RemotePath)/game-servers/project-zomboid && docker build -t arcadenode/project-zomboid:latest ."
    
    Write-Success "Project Zomboid image built"
    
    # Also load to node
    Write-Info "Loading Project Zomboid image to game node..."
    Load-ImageToNode "arcadenode/project-zomboid:latest"
}

function Build-Minecraft {
    Write-Host "`n=== Building Minecraft ===" -ForegroundColor Magenta
    

    $mcLocal = Join-Path $Config.LocalPath "game-servers\minecraft"
    Copy-ToRemote "$mcLocal\*" "game-servers/minecraft/"
    
    Write-Info "Building Minecraft image..."
    Invoke-Remote "cd $($Config.RemotePath)/game-servers/minecraft && docker build -t arcadenode/minecraft:latest ."
    
    Write-Success "Minecraft image built"
    
    # Also load to node
    Write-Info "Loading Minecraft image to game node..."
    Load-ImageToNode "arcadenode/minecraft:latest"
}

function Build-AllGames {
    Write-Host "`n=== Building All Game Servers ===" -ForegroundColor Magenta
    

    Sync-GameServers
    
    $games = @("minecraft", "minecraft-bedrock", "project-zomboid", "arma-reforger")
    
    foreach ($game in $games) {
        Write-Info "Building $game..."
        $result = Invoke-Remote "cd $($Config.RemotePath)/game-servers/$game && docker build -t arcadenode/${game}:latest . 2>&1"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$game built"
            Write-Info "Loading $game to game node..."
            Load-ImageToNode "arcadenode/${game}:latest"
        } else {
            Write-Warn "$game build failed or not available"
        }
    }
}

#===============================================================================
#  NODE IMAGE MANAGEMENT
#===============================================================================

function Load-ImageToNode {
    param([string]$ImageName)
    
    Write-Host "  Loading $ImageName to arcadenode_node..." -ForegroundColor DarkGray
    
    # Save image from host Docker, pipe to node's Docker
    Invoke-Remote "docker save $ImageName | docker exec -i arcadenode_node docker load"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "$ImageName loaded to node"
    } else {
        Write-Err "Failed to load $ImageName to node"
    }
}

function Load-AllImagesToNode {
    Write-Host "`n=== Loading Game Images to Node ===" -ForegroundColor Magenta
    
    # First check what images exist on the host
    Write-Info "Checking available game server images..."
    $images = @("arcadenode/minecraft", "arcadenode/minecraft-bedrock", "arcadenode/project-zomboid", "arcadenode/arma-reforger")
    
    foreach ($image in $images) {
        $exists = Invoke-Remote "docker images -q ${image}:latest 2>/dev/null"
        if ($exists) {
            Write-Info "Loading $image to node..."
            Load-ImageToNode "${image}:latest"
        } else {
            Write-Warn "$image not found on host - build it first with: .\quick-deploy.ps1 games"
        }
    }
    
    Write-Host ""
    Write-Info "Images available in game node:"
    Invoke-Remote "docker exec arcadenode_node docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"
}

#===============================================================================
#  UTILITY FUNCTIONS
#===============================================================================

function Show-Status {

    Write-Host "`n=== Container Status ===" -ForegroundColor Magenta
    Invoke-Remote "docker ps --filter 'name=arcadenode' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
}

function Show-ServiceLogs {
    param(
        [string]$Service,
        [int]$Lines = 50
    )
    

    Write-Host "`n=== Logs: $Service ===" -ForegroundColor Magenta
    
    if ($Service) {
        $container = "arcadenode_$Service"
        if ($Follow) {
            Invoke-Remote "docker logs -f $container"
        } else {
            Invoke-Remote "docker logs --tail=$Lines $container 2>&1"
        }
    } else {
        Invoke-Remote "cd $($Config.RemotePath) && docker compose logs --tail=$Lines"
    }
}

function Open-Shell {
    param([string]$Service = "backend")
    

    Write-Info "Opening shell on $Service..."
    $container = "arcadenode_$Service"
    
    # Use interactive SSH (need to bypass multiplexing for interactive session)
    $remote = Get-Remote
    ssh -t $remote "docker exec -it $container /bin/bash 2>/dev/null || docker exec -it $container /bin/sh"
}

function Reset-Database {
    Write-Host "`n=== Resetting Database ===" -ForegroundColor Magenta
    Write-Warn "This will DELETE all data in the database!"
    
    $confirm = Read-Host "Type 'yes' to confirm"
    if ($confirm -ne "yes") {
        Write-Info "Cancelled"
        return
    }
    

    Write-Info "Stopping backend..."
    Invoke-Remote "docker stop arcadenode_backend 2>/dev/null || true"
    
    $saPassword = Get-SaPassword
    Write-Info "Dropping database..."
    Invoke-Remote -Quiet "docker exec arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$saPassword' -C -Q 'DROP DATABASE IF EXISTS ArcadeNode'"
    
    Write-Info "Restarting backend (will recreate database)..."
    Invoke-Remote "docker start arcadenode_backend"
    
    Start-Sleep -Seconds 10
    Write-Success "Database reset complete. The admin account is reseeded from ADMIN_PASSWORD (or a random password printed in the backend logs)."
}

function Reset-AdminPassword {
    Write-Host "`n=== Reset Admin Password ===" -ForegroundColor Magenta

    $newPassword = Read-Host "New admin password" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPassword))
    if ([string]::IsNullOrWhiteSpace($plain)) {
        Write-Err "Password cannot be empty"
        return
    }

    $saPassword = Get-SaPassword
    
    # Generate fresh hash using Python on the server (if bcrypt is installed)
    Write-Info "Generating bcrypt hash on server..."
    $hashScript = "import bcrypt,sys; print(bcrypt.hashpw(sys.stdin.readline().rstrip('\n').encode(), bcrypt.gensalt(rounds=11)).decode())"
    $hashResult = $plain | ssh $(Get-Remote) "python3 -c `"$hashScript`" 2>/dev/null"
    
    if ($hashResult -and $hashResult.StartsWith('$2')) {
        Write-Info "Got fresh hash: $($hashResult.Substring(0, 30))..."
        
        # Create SQL file on server and execute
        Invoke-Remote "echo `"UPDATE Users SET PasswordHash = '$hashResult' WHERE Username = 'admin';`" > /tmp/reset_pwd.sql"
        Invoke-Remote -Quiet "docker exec -i arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$saPassword' -C -d ArcadeNode < /tmp/reset_pwd.sql"
        Invoke-Remote "rm /tmp/reset_pwd.sql"
        
        Write-Success "Admin password reset."
    } else {
        Write-Warn "Could not generate bcrypt hash. Trying alternative method..."
        Write-Info "Deleting admin user (will be recreated on backend restart)..."
        Invoke-Remote "echo 'DELETE FROM Users WHERE Username = ''admin''' > /tmp/reset_pwd.sql"
        Invoke-Remote -Quiet "docker exec -i arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '$saPassword' -C -d ArcadeNode < /tmp/reset_pwd.sql"
        Invoke-Remote "rm /tmp/reset_pwd.sql"
        Invoke-Remote "docker restart arcadenode_backend"
        Start-Sleep -Seconds 5
        Write-Success "Admin user deleted. It is reseeded from ADMIN_PASSWORD (or a random password printed in the backend logs)."
    }
}

function Clean-Containers {
    Write-Host "`n=== Cleaning Containers ===" -ForegroundColor Magenta
    

    Write-Info "Stopping all arcadenode containers..."
    Invoke-Remote "docker ps -a --filter 'name=arcadenode' -q | xargs -r docker stop"
    
    Write-Info "Removing all arcadenode containers..."
    Invoke-Remote "docker ps -a --filter 'name=arcadenode' -q | xargs -r docker rm"
    
    Write-Info "Removing dangling images..."
    Invoke-Remote "docker image prune -f"
    
    Write-Success "Cleanup complete"
}

function Setup-SSHKey {
    Write-Host "`n=== Setting Up SSH Key for Passwordless Access ===" -ForegroundColor Magenta
    
    $sshDir = "$env:USERPROFILE\.ssh"
    $keyFile = "$sshDir\id_ed25519"
    $pubKeyFile = "$keyFile.pub"
    
    # Check if key exists
    if (-not (Test-Path $pubKeyFile)) {
        Write-Info "No SSH key found. Generating new ED25519 key..."
        
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        
        ssh-keygen -t ed25519 -f $keyFile -N '""'
        
        if (-not (Test-Path $pubKeyFile)) {
            Write-Err "Failed to generate SSH key"
            return
        }
        Write-Success "SSH key generated"
    } else {
        Write-Info "Using existing SSH key: $pubKeyFile"
    }
    
    # Read public key
    $pubKey = Get-Content $pubKeyFile -Raw
    Write-Host ""
    Write-Info "Copying public key to remote server..."
    Write-Host "  You'll need to enter your password ONE LAST TIME" -ForegroundColor Yellow
    Write-Host ""
    
    # Copy key to remote server
    $remote = Get-Remote
    ssh $remote "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$($pubKey.Trim())' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "SSH key installed! You should no longer need to enter a password."
        Write-Host ""
        Write-Info "Testing connection..."
        ssh $remote "echo 'Passwordless SSH working!'"
    } else {
        Write-Err "Failed to install SSH key"
    }
}

function Show-Help {
    Write-Host @"

ArcadeNode Quick Deploy Script
==============================

Configured Remote: $($Config.RemoteUser)@$($Config.RemoteHost):$($Config.RemotePath)

USAGE: .\quick-deploy.ps1 <command> [target] [-NoCache] [-Follow]

DEPLOYMENT COMMANDS:
  all              Full deployment (sync, build, restart all)
  backend          Deploy backend only
  frontend         Deploy frontend only

GAME SERVER BUILDS:
  games            Build all game server images (and load to node)
  pz               Build Project Zomboid image (and load to node)
  minecraft        Build Minecraft image (and load to node)
  loadimages       Load all existing images to game node

SYNC COMMANDS:
  sync             Sync all files to remote (no build)

MANAGEMENT COMMANDS:
  rebuild <svc>    Rebuild and restart a service (backend, frontend)
  restart <svc>    Restart a service without rebuilding
  logs <svc>       View logs (-Follow for live logs)
  status           Show container status
  shell <svc>      Open shell in container (default: backend)

DATABASE COMMANDS:
  reset-db         Reset database (DELETES ALL DATA)
  reset-password   Reset the admin password (prompts for the new value)

SETUP:
  setup-ssh-key    Setup SSH key for passwordless access

CLEANUP:
  clean-containers Stop and remove all arcadenode containers

OPTIONS:
  -NoCache         Build without using Docker cache
  -Follow          Follow log output (for 'logs' command)

EXAMPLES:
  .\quick-deploy.ps1 backend              # Deploy backend changes
  .\quick-deploy.ps1 frontend -NoCache    # Rebuild frontend from scratch
  .\quick-deploy.ps1 logs backend -Follow # Follow backend logs
  .\quick-deploy.ps1 pz                   # Rebuild Project Zomboid image
  .\quick-deploy.ps1 shell backend        # Open shell in backend container
  .\quick-deploy.ps1 status               # Check container status

"@ -ForegroundColor White
}

#===============================================================================
#  MAIN
#===============================================================================

switch ($Command) {
    "all"              { Deploy-All -NoCache:$NoCache }
    "backend"          { Deploy-Backend -NoCache:$NoCache }
    "frontend"         { Deploy-Frontend -NoCache:$NoCache }
    "games"            { Build-AllGames }
    "pz"               { Build-ProjectZomboid }
    "minecraft"        { Build-Minecraft }
    "sync"             { Sync-All }
    "rebuild"          { 
        if ($Target -eq "backend") { Deploy-Backend -NoCache:$NoCache }
        elseif ($Target -eq "frontend") { Deploy-Frontend -NoCache:$NoCache }
        else { Write-Err "Specify target: backend or frontend" }
    }
    "restart"          { 
        if ($Target) { Restart-RemoteService $Target }
        else { Invoke-Remote "cd $($Config.RemotePath) && docker compose restart" }
    }
    "logs"             { Show-ServiceLogs -Service $Target }
    "status"           { Show-Status }
    "shell"            { Open-Shell -Service $(if ($Target) { $Target } else { "backend" }) }
    "reset-db"         { Reset-Database }
    "reset-password"   { Reset-AdminPassword }
    "clean-containers" { Clean-Containers }
    "setup-ssh-key"    { Setup-SSHKey }
    "loadimages"       { Load-AllImagesToNode }
    "help"             { Show-Help }
    default            { Show-Help }
}
