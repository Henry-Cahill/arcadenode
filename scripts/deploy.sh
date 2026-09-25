#!/bin/bash
#===============================================================================
#  ArcadeNode - Comprehensive Deployment Script
#===============================================================================
#  This script handles all deployment tasks for the ArcadeNode Game Server Panel
#  including building, deploying, and managing the entire infrastructure.
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GAME_SERVERS_DIR="${PROJECT_ROOT}/game-servers"
PANEL_DIR="${PROJECT_ROOT}"
COMPOSE_FILE="${PANEL_DIR}/docker-compose.yml"

# Default values
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH="~/ArcadeNode"

# Functions
print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     █████╗ ██████╗  ██████╗ █████╗ ██████╗ ███████╗              ║"
    echo "║    ██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝              ║"
    echo "║    ███████║██████╔╝██║     ███████║██║  ██║█████╗                ║"
    echo "║    ██╔══██║██╔══██╗██║     ██╔══██║██║  ██║██╔══╝                ║"
    echo "║    ██║  ██║██║  ██║╚██████╗██║  ██║██████╔╝███████╗              ║"
    echo "║    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝ ╚══════╝              ║"
    echo "║                                                                   ║"
    echo "║    ███╗   ██╗ ██████╗ ██████╗ ███████╗                           ║"
    echo "║    ████╗  ██║██╔═══██╗██╔══██╗██╔════╝                           ║"
    echo "║    ██╔██╗ ██║██║   ██║██║  ██║█████╗                             ║"
    echo "║    ██║╚██╗██║██║   ██║██║  ██║██╔══╝                             ║"
    echo "║    ██║ ╚████║╚██████╔╝██████╔╝███████╗                           ║"
    echo "║    ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝                           ║"
    echo "║                                                                   ║"
    echo "║              Comprehensive Deployment System                      ║"
    echo "║                        v1.0.0                                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Never hardcode the SA password - read it from the environment or the gitignored .env
get_sa_password() {
    if [[ -n "${MSSQL_SA_PASSWORD:-}" ]]; then
        echo "${MSSQL_SA_PASSWORD}"
        return 0
    fi

    local env_file="${PROJECT_ROOT}/.env"
    if [[ -f "${env_file}" ]]; then
        local value
        value="$(grep -m1 '^[[:space:]]*MSSQL_SA_PASSWORD[[:space:]]*=' "${env_file}" | cut -d= -f2- | tr -d '"'"'"'')"
        if [[ -n "${value}" ]]; then
            echo "${value}"
            return 0
        fi
    fi

    log_error "MSSQL_SA_PASSWORD is not set. Export it or add it to ${env_file} (see .env.example)."
    exit 1
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi
    log_success "Docker is available"
    return 0
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        log_success "Docker Compose is available"
        return 0
    elif command -v docker-compose &> /dev/null; then
        log_success "Docker Compose (standalone) is available"
        return 0
    else
        log_error "Docker Compose is not installed"
        return 1
    fi
}

#===============================================================================
#  BUILD FUNCTIONS
#===============================================================================

build_game_servers() {
    print_section "Building Game Server Images"
    
    local games=("minecraft" "minecraft-bedrock" "project-zomboid" "arma-reforger")
    local built=0
    local failed=0
    
    for game in "${games[@]}"; do
        local game_dir="${GAME_SERVERS_DIR}/${game}"
        if [[ -d "${game_dir}" ]] && [[ -f "${game_dir}/Dockerfile" ]]; then
            log_info "Building ${game}..."
            if docker build -t "arcadenode/${game}:latest" "${game_dir}" 2>&1; then
                log_success "Built arcadenode/${game}:latest"
                ((built++))
            else
                log_error "Failed to build ${game}"
                ((failed++))
            fi
        else
            log_warning "Game directory not found: ${game_dir}"
            ((failed++))
        fi
    done
    
    echo ""
    log_info "Build Summary: ${built} succeeded, ${failed} failed"
}

load_images_to_node() {
    print_section "Loading Game Server Images into Docker Node"
    
    local node_container="${1:-arcadenode_node}"
    local games=("minecraft" "minecraft-bedrock" "project-zomboid" "arma-reforger")
    local loaded=0
    local failed=0
    
    # Check if node container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${node_container}$"; then
        log_error "Docker node container '${node_container}' is not running"
        log_info "Make sure the panel is deployed first with 'docker compose up -d'"
        return 1
    fi
    
    log_info "Node container found: ${node_container}"
    
    for game in "${games[@]}"; do
        local image="arcadenode/${game}:latest"
        
        # Check if image exists locally
        if ! docker image inspect "${image}" &>/dev/null; then
            log_warning "Image ${image} not found locally, building..."
            local game_dir="${GAME_SERVERS_DIR}/${game}"
            if [[ -d "${game_dir}" ]] && [[ -f "${game_dir}/Dockerfile" ]]; then
                if ! docker build -t "${image}" "${game_dir}"; then
                    log_error "Failed to build ${image}"
                    ((failed++))
                    continue
                fi
            else
                log_error "Game directory not found: ${game_dir}"
                ((failed++))
                continue
            fi
        fi
        
        log_info "Loading ${image} into node..."
        
        # Save image to tar and load into Docker-in-Docker node
        if docker save "${image}" | docker exec -i "${node_container}" docker load; then
            log_success "Loaded ${image} into node"
            ((loaded++))
        else
            log_error "Failed to load ${image} into node"
            ((failed++))
        fi
    done
    
    echo ""
    log_info "Load Summary: ${loaded} succeeded, ${failed} failed"
    
    # Show images in node
    echo ""
    log_info "Images available in node:"
    docker exec "${node_container}" docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
}

build_panel() {
    print_section "Building ArcadeNode Panel"
    
    cd "${PANEL_DIR}"
    
    log_info "Building backend..."
    if docker compose build backend 2>&1; then
        log_success "Backend built successfully"
    else
        log_error "Backend build failed"
        return 1
    fi
    
    log_info "Building frontend..."
    if docker compose build frontend 2>&1; then
        log_success "Frontend built successfully"
    else
        log_error "Frontend build failed"
        return 1
    fi
    
    log_success "Panel build complete!"
}

build_all() {
    print_section "Building All Components"
    build_game_servers
    build_panel
    log_success "All builds complete!"
}

#===============================================================================
#  LOCAL DEPLOYMENT FUNCTIONS
#===============================================================================

deploy_local() {
    print_section "Deploying ArcadeNode Locally"
    
    cd "${PANEL_DIR}"
    
    log_info "Starting services..."
    docker compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps | grep -q "healthy"; then
            log_success "SQL Server is healthy"
            break
        fi
        ((attempt++))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "Services may not be fully ready yet"
    fi
    
    # Wait for Docker-in-Docker node to be ready
    log_info "Waiting for Docker node to be ready..."
    local node_ready=0
    for i in {1..30}; do
        if docker exec arcadenode_node docker info &>/dev/null; then
            node_ready=1
            break
        fi
        sleep 2
    done
    
    if [ $node_ready -eq 1 ]; then
        log_success "Docker node is ready"
        # Load game server images into the node
        load_images_to_node "arcadenode_node"
    else
        log_warning "Docker node may not be ready, skipping image loading"
        log_info "You can manually load images later with: ./deploy.sh load-images"
    fi
    
    echo ""
    log_success "ArcadeNode deployed successfully!"
    echo ""
    echo -e "${WHITE}Access Points:${NC}"
    echo -e "  ${CYAN}Frontend:${NC} http://localhost:3000"
    echo -e "  ${CYAN}Backend API:${NC} http://localhost:5000"
    echo -e "  ${CYAN}Swagger:${NC} http://localhost:5000/swagger"
    echo ""
}

stop_local() {
    print_section "Stopping ArcadeNode"
    cd "${PANEL_DIR}"
    docker compose down
    log_success "ArcadeNode stopped"
}

restart_local() {
    print_section "Restarting ArcadeNode"
    cd "${PANEL_DIR}"
    docker compose restart
    log_success "ArcadeNode restarted"
}

show_local_status() {
    print_section "ArcadeNode Status"
    cd "${PANEL_DIR}"
    docker compose ps
    echo ""
    echo -e "${WHITE}Container Logs (last 10 lines each):${NC}"
    echo ""
    docker compose logs --tail=10
}

show_logs() {
    local service="${1:-}"
    cd "${PANEL_DIR}"
    
    if [[ -z "$service" ]]; then
        docker compose logs -f
    else
        docker compose logs -f "$service"
    fi
}

#===============================================================================
#  REMOTE DEPLOYMENT FUNCTIONS
#===============================================================================

configure_remote() {
    print_section "Configure Remote Deployment"
    
    echo -e "${WHITE}Current Configuration:${NC}"
    [[ -n "$REMOTE_HOST" ]] && echo "  Host: $REMOTE_HOST" || echo "  Host: (not set)"
    [[ -n "$REMOTE_USER" ]] && echo "  User: $REMOTE_USER" || echo "  User: (not set)"
    echo "  Path: $REMOTE_PATH"
    echo ""
    
    read -p "Enter remote host (IP or hostname): " host
    read -p "Enter remote user: " user
    read -p "Enter remote path [${REMOTE_PATH}]: " path
    
    REMOTE_HOST="${host}"
    REMOTE_USER="${user}"
    [[ -n "$path" ]] && REMOTE_PATH="$path"
    
    # Save to config file
    cat > "${PROJECT_ROOT}/.deploy-config" << EOF
REMOTE_HOST="${REMOTE_HOST}"
REMOTE_USER="${REMOTE_USER}"
REMOTE_PATH="${REMOTE_PATH}"
EOF
    
    log_success "Configuration saved to .deploy-config"
}

load_remote_config() {
    if [[ -f "${PROJECT_ROOT}/.deploy-config" ]]; then
        source "${PROJECT_ROOT}/.deploy-config"
    fi
}

sync_to_remote() {
    print_section "Syncing Files to Remote Server"
    
    if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
        log_error "Remote configuration not set. Run 'configure remote' first."
        return 1
    fi
    
    local remote="${REMOTE_USER}@${REMOTE_HOST}"
    
    log_info "Creating remote directories..."
    ssh "${remote}" "mkdir -p ${REMOTE_PATH}/{backend/ServerPanel.API/{Controllers,DTOs,Services,Models,Data},frontend/src/{pages/admin,components,services,types,stores},game-servers/{minecraft,minecraft-bedrock,project-zomboid,arma-reforger}}"
    
    log_info "Syncing panel files..."
    rsync -avz --progress \
        --exclude 'node_modules' \
        --exclude 'bin' \
        --exclude 'obj' \
        --exclude '.git' \
        --exclude '*.log' \
        "${PANEL_DIR}/" "${remote}:${REMOTE_PATH}/"
    
    log_success "Files synced successfully!"
}

deploy_remote() {
    print_section "Deploying to Remote Server"
    
    if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
        log_error "Remote configuration not set. Run 'configure remote' first."
        return 1
    fi
    
    local remote="${REMOTE_USER}@${REMOTE_HOST}"
    
    # Sync files first
    sync_to_remote
    
    log_info "Building and starting services on remote..."
    ssh "${remote}" "cd ${REMOTE_PATH} && docker compose build --no-cache && docker compose up -d"
    
    log_info "Waiting for services to start..."
    sleep 10
    
    log_info "Checking service status..."
    ssh "${remote}" "cd ${REMOTE_PATH} && docker compose ps"
    
    echo ""
    log_success "Remote deployment complete!"
    echo ""
    echo -e "${WHITE}Access Points:${NC}"
    echo -e "  ${CYAN}Frontend:${NC} http://${REMOTE_HOST}:3000"
    echo -e "  ${CYAN}Backend API:${NC} http://${REMOTE_HOST}:5000"
    echo ""
}

remote_status() {
    if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
        log_error "Remote configuration not set."
        return 1
    fi
    
    local remote="${REMOTE_USER}@${REMOTE_HOST}"
    
    print_section "Remote Server Status"
    ssh "${remote}" "cd ${REMOTE_PATH} && docker compose ps"
}

remote_logs() {
    if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
        log_error "Remote configuration not set."
        return 1
    fi
    
    local remote="${REMOTE_USER}@${REMOTE_HOST}"
    local service="${1:-}"
    
    if [[ -z "$service" ]]; then
        ssh "${remote}" "cd ${REMOTE_PATH} && docker compose logs --tail=50"
    else
        ssh "${remote}" "cd ${REMOTE_PATH} && docker compose logs --tail=50 ${service}"
    fi
}

#===============================================================================
#  GAME SERVER MANAGEMENT
#===============================================================================

deploy_game_server() {
    print_section "Deploy Game Server"
    
    echo "Available game servers:"
    echo "  1) Minecraft Java Edition"
    echo "  2) Minecraft Bedrock Edition"
    echo "  3) Project Zomboid"
    echo "  4) Arma Reforger"
    echo ""
    read -p "Select game (1-4): " choice
    
    local game=""
    local ports=""
    
    case $choice in
        1) game="minecraft"; ports="-p 25565:25565 -p 25575:25575" ;;
        2) game="minecraft-bedrock"; ports="-p 19132:19132/udp -p 19133:19133/udp" ;;
        3) game="project-zomboid"; ports="-p 16261:16261/udp -p 16262:16262/udp -p 27015:27015" ;;
        4) game="arma-reforger"; ports="-p 2001:2001/udp -p 17777:17777/udp" ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac
    
    read -p "Enter server name: " server_name
    read -p "Enter memory limit (e.g., 2G): " memory
    
    local container_name="${server_name// /_}"
    
    log_info "Starting ${game} server: ${server_name}..."
    
    docker run -d \
        --name "${container_name}" \
        --memory="${memory:-2G}" \
        ${ports} \
        --restart unless-stopped \
        "arcadenode/${game}:latest"
    
    log_success "Game server deployed: ${container_name}"
    docker ps --filter "name=${container_name}"
}

list_game_servers() {
    print_section "Running Game Servers"
    docker ps --filter "ancestor=arcadenode/minecraft:latest" \
              --filter "ancestor=arcadenode/minecraft-bedrock:latest" \
              --filter "ancestor=arcadenode/project-zomboid:latest" \
              --filter "ancestor=arcadenode/arma-reforger:latest" \
              --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

#===============================================================================
#  DATABASE MANAGEMENT
#===============================================================================

backup_database() {
    print_section "Database Backup"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="arcadenode_backup_${timestamp}.bak"
    
    log_info "Creating database backup..."
    
    docker exec arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$(get_sa_password)" -C \
        -Q "BACKUP DATABASE ArcadeNode TO DISK='/var/opt/mssql/backup/${backup_file}'"
    
    docker cp "arcadenode_sqlserver:/var/opt/mssql/backup/${backup_file}" "./${backup_file}"
    
    log_success "Backup created: ${backup_file}"
}

reset_database() {
    print_section "Reset Database"
    
    log_warning "This will delete all data in the database!"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cancelled"
        return
    fi
    
    log_info "Dropping and recreating database..."
    
    docker exec arcadenode_sqlserver /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$(get_sa_password)" -C \
        -Q "DROP DATABASE IF EXISTS ArcadeNode; CREATE DATABASE ArcadeNode;"
    
    log_info "Restarting backend to run migrations..."
    docker restart arcadenode_backend
    
    log_success "Database reset complete"
}

#===============================================================================
#  MAINTENANCE
#===============================================================================

cleanup_docker() {
    print_section "Docker Cleanup"
    
    log_info "Removing stopped containers..."
    docker container prune -f
    
    log_info "Removing unused images..."
    docker image prune -f
    
    log_info "Removing unused volumes..."
    docker volume prune -f
    
    log_info "Removing unused networks..."
    docker network prune -f
    
    log_success "Cleanup complete"
    
    echo ""
    docker system df
}

update_all() {
    print_section "Update All Components"
    
    log_info "Pulling latest base images..."
    docker pull mcr.microsoft.com/mssql/server:2025-latest
    docker pull mcr.microsoft.com/dotnet/sdk:9.0
    docker pull mcr.microsoft.com/dotnet/aspnet:9.0
    docker pull node:20-alpine
    docker pull nginx:alpine
    docker pull docker:dind
    
    log_info "Rebuilding all images..."
    build_all
    
    log_success "Update complete"
}

#===============================================================================
#  INTERACTIVE MENU
#===============================================================================

show_menu() {
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                        MAIN MENU                                  ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}  BUILD${NC}"
    echo "    1)  Build Game Server Images"
    echo "    2)  Build Panel (Backend + Frontend)"
    echo "    3)  Build All"
    echo ""
    echo -e "${CYAN}  LOCAL DEPLOYMENT${NC}"
    echo "    4)  Deploy Locally"
    echo "    5)  Stop Local Services"
    echo "    6)  Restart Local Services"
    echo "    7)  Show Local Status"
    echo "    8)  View Logs"
    echo ""
    echo -e "${CYAN}  REMOTE DEPLOYMENT${NC}"
    echo "    9)  Configure Remote Server"
    echo "    10) Deploy to Remote Server"
    echo "    11) Sync Files to Remote"
    echo "    12) Remote Status"
    echo "    13) Remote Logs"
    echo ""
    echo -e "${CYAN}  GAME SERVERS${NC}"
    echo "    14) Deploy Game Server"
    echo "    15) List Game Servers"
    echo "    16) Load Images to Node"
    echo ""
    echo -e "${CYAN}  DATABASE${NC}"
    echo "    17) Backup Database"
    echo "    18) Reset Database"
    echo ""
    echo -e "${CYAN}  MAINTENANCE${NC}"
    echo "    19) Docker Cleanup"
    echo "    20) Update All"
    echo ""
    echo "    0)  Exit"
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════${NC}"
}

#===============================================================================
#  MAIN
#===============================================================================

main() {
    # Load any saved configuration
    load_remote_config
    
    # Check for command-line arguments
    if [[ $# -gt 0 ]]; then
        case "$1" in
            build-games)     build_game_servers ;;
            build-panel)     build_panel ;;
            build-all)       build_all ;;
            deploy)          deploy_local ;;
            stop)            stop_local ;;
            restart)         restart_local ;;
            status)          show_local_status ;;
            logs)            show_logs "${2:-}" ;;
            deploy-remote)   deploy_remote ;;
            sync)            sync_to_remote ;;
            remote-status)   remote_status ;;
            remote-logs)     remote_logs "${2:-}" ;;
            deploy-game)     deploy_game_server ;;
            list-games)      list_game_servers ;;
            backup)          backup_database ;;
            cleanup)         cleanup_docker ;;
            update)          update_all ;;
            load-images)     load_images_to_node "${2:-arcadenode_node}" ;;
            help|--help|-h)
                echo "Usage: $0 [command]"
                echo ""
                echo "Commands:"
                echo "  build-games     Build game server Docker images"
                echo "  build-panel     Build ArcadeNode panel"
                echo "  build-all       Build everything"
                echo "  deploy          Deploy locally"
                echo "  stop            Stop local services"
                echo "  restart         Restart local services"
                echo "  status          Show local status"
                echo "  logs [service]  View logs"
                echo "  deploy-remote   Deploy to remote server"
                echo "  sync            Sync files to remote"
                echo "  remote-status   Show remote status"
                echo "  remote-logs     View remote logs"
                echo "  deploy-game     Deploy a game server"
                echo "  list-games      List running game servers"
                echo "  backup          Backup database"
                echo "  cleanup         Docker cleanup"
                echo "  update          Update all components"
                echo "  load-images     Load game server images into Docker node"
                echo ""
                echo "Run without arguments for interactive menu."
                ;;
            *)
                log_error "Unknown command: $1"
                echo "Run '$0 help' for usage."
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Interactive mode
    print_banner
    
    # Check prerequisites
    check_docker || exit 1
    check_docker_compose || exit 1
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1)  build_game_servers ;;
            2)  build_panel ;;
            3)  build_all ;;
            4)  deploy_local ;;
            5)  stop_local ;;
            6)  restart_local ;;
            7)  show_local_status ;;
            8)  read -p "Service (blank for all): " svc; show_logs "$svc" ;;
            9)  configure_remote ;;
            10) deploy_remote ;;
            11) sync_to_remote ;;
            12) remote_status ;;
            13) read -p "Service (blank for all): " svc; remote_logs "$svc" ;;
            14) deploy_game_server ;;
            15) list_game_servers ;;
            16) load_images_to_node "arcadenode_node" ;;
            17) backup_database ;;
            18) reset_database ;;
            19) cleanup_docker ;;
            20) update_all ;;
            0)  echo "Goodbye!"; exit 0 ;;
            *)  log_error "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

main "$@"
