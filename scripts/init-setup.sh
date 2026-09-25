#!/bin/bash
# ArcadeNode Initial Setup Script
# Run this on first deployment to build all game server images

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GAME_SERVERS_DIR="${PROJECT_ROOT}/game-servers"
DATA_DIR="${PROJECT_ROOT}/data"
SERVERS_DIR="${DATA_DIR}/servers"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "    _                        _        _   _           _      "
    echo "   / \   _ __ ___ __ _  __| | ___  | \ | | ___   __| | ___ "
    echo "  / _ \ | '__/ __/ _\` |/ _\` |/ _ \ |  \| |/ _ \ / _\` |/ _ \\"
    echo " / ___ \| | | (_| (_| | (_| |  __/ | |\  | (_) | (_| |  __/"
    echo "/_/   \_\_|  \___\__,_|\__,_|\___| |_| \_|\___/ \__,_|\___|"
    echo -e "${NC}"
    echo -e "${BOLD}Game Server Management Panel - Initial Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "\n${MAGENTA}▶ $1${NC}"
}

check_requirements() {
    print_step "Checking system requirements..."
    
    local missing=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    else
        print_success "Docker found: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing+=("docker-compose")
    else
        if docker compose version &> /dev/null; then
            print_success "Docker Compose found: $(docker compose version | cut -d' ' -f4)"
        else
            print_success "Docker Compose found: $(docker-compose --version | cut -d' ' -f3 | tr -d ',')"
        fi
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        missing+=("docker-daemon")
    else
        print_success "Docker daemon is running"
    fi
    
    # Check available disk space (need at least 10GB)
    local available_space=$(df -BG "${PROJECT_ROOT}" | tail -1 | awk '{print $4}' | tr -d 'G')
    if [ "$available_space" -lt 10 ]; then
        print_warning "Low disk space: ${available_space}GB available (recommended: 10GB+)"
    else
        print_success "Disk space: ${available_space}GB available"
    fi
    
    # Check available memory
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 4 ]; then
        print_warning "Low memory: ${total_mem}GB (recommended: 4GB+)"
    else
        print_success "Memory: ${total_mem}GB available"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        print_error "Missing requirements: ${missing[*]}"
        echo ""
        echo "Please install the missing components and try again."
        exit 1
    fi
    
    print_success "All requirements met!"
}

create_directories() {
    print_step "Creating directory structure..."
    
    mkdir -p "${DATA_DIR}"
    mkdir -p "${SERVERS_DIR}"
    mkdir -p "${DATA_DIR}/backups"
    mkdir -p "${DATA_DIR}/logs"
    mkdir -p "${DATA_DIR}/configs"
    
    print_success "Created ${DATA_DIR}"
    print_success "Created ${SERVERS_DIR}"
    print_success "Created ${DATA_DIR}/backups"
    print_success "Created ${DATA_DIR}/logs"
    print_success "Created ${DATA_DIR}/configs"
}

build_images() {
    print_step "Building game server images..."
    
    if [ ! -d "${GAME_SERVERS_DIR}" ]; then
        print_error "Game servers directory not found: ${GAME_SERVERS_DIR}"
        exit 1
    fi
    
    cd "${GAME_SERVERS_DIR}"
    
    if [ -f "./build.sh" ]; then
        chmod +x ./build.sh
        ./build.sh
    else
        print_warning "build.sh not found, building manually..."
        
        local images=("minecraft" "minecraft-bedrock" "project-zomboid" "arma-reforger")
        
        for img in "${images[@]}"; do
            if [ -d "./${img}" ]; then
                print_status "Building ${img}..."
                docker build -t "arcadenode/${img}:latest" "./${img}"
                print_success "${img} built"
            fi
        done
    fi
    
    cd "${PROJECT_ROOT}"
}

setup_network() {
    print_step "Setting up Docker network..."
    
    if docker network inspect arcadenode &> /dev/null; then
        print_success "Network 'arcadenode' already exists"
    else
        docker network create arcadenode
        print_success "Created network 'arcadenode'"
    fi
}

create_env_file() {
    print_step "Creating environment configuration..."
    
    local env_file="${PROJECT_ROOT}/.env"
    
    if [ -f "${env_file}" ]; then
        print_warning ".env file already exists, skipping..."
        return
    fi
    
    # Generate random passwords
    local db_password=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    local jwt_secret=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)
    local admin_password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    
    cat > "${env_file}" << EOF
# ArcadeNode Configuration
# Generated on $(date)

# Database
DB_HOST=sqlserver
DB_PORT=1433
DB_NAME=ArcadeNodePanel
DB_USER=sa
DB_PASSWORD=${db_password}

# JWT Authentication
JWT_SECRET=${jwt_secret}
JWT_EXPIRY=24h

# Admin Account
ADMIN_USERNAME=admin
ADMIN_PASSWORD=${admin_password}
ADMIN_EMAIL=admin@localhost

# Server Settings
API_PORT=5000
FRONTEND_PORT=3000
NODE_PORT=8080

# Docker Socket
DOCKER_SOCKET=/var/run/docker.sock

# Data Paths
DATA_DIR=${DATA_DIR}
SERVERS_DIR=${SERVERS_DIR}
BACKUPS_DIR=${DATA_DIR}/backups
LOGS_DIR=${DATA_DIR}/logs
EOF
    
    chmod 600 "${env_file}"
    
    print_success "Created .env file"
    echo ""
    print_warning "IMPORTANT: Save these credentials!"
    echo -e "  Admin Username: ${CYAN}admin${NC}"
    echo -e "  Admin Password: ${CYAN}${admin_password}${NC}"
    echo -e "  Database Password: ${CYAN}${db_password}${NC}"
    echo ""
}

show_summary() {
    print_step "Setup Complete!"
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}                    Setup Summary${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${CYAN}Built Images:${NC}"
    docker images --filter "reference=arcadenode/*" --format "  • {{.Repository}}:{{.Tag}} ({{.Size}})"
    
    echo ""
    echo -e "${CYAN}Directory Structure:${NC}"
    echo "  • ${DATA_DIR}"
    echo "    ├── servers/     (game server data)"
    echo "    ├── backups/     (server backups)"
    echo "    ├── logs/        (server logs)"
    echo "    └── configs/     (configuration files)"
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Start the panel: docker-compose up -d"
    echo "  2. Access the panel: http://localhost:3000"
    echo "  3. Deploy a server: ./scripts/deploy-wizard.sh"
    echo ""
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main execution
main() {
    print_banner
    
    echo "This script will set up ArcadeNode and build all game server images."
    echo ""
    read -p "Continue with setup? [Y/n] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_requirements
    create_directories
    setup_network
    build_images
    create_env_file
    show_summary
}

# Run with optional flags
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo "  --skip-build    Skip building Docker images"
        echo "  --rebuild       Force rebuild all images"
        echo ""
        exit 0
        ;;
    --skip-build)
        SKIP_BUILD=true
        ;;
    --rebuild)
        REBUILD=true
        ;;
esac

main
