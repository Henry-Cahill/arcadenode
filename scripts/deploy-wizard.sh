#!/bin/bash
# ArcadeNode Game Server Deployment Wizard
# Interactive wizard for deploying game servers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WIZARDS_DIR="${PROJECT_ROOT}/game-servers/wizards"
DATA_DIR="${PROJECT_ROOT}/data"
SERVERS_DIR="${DATA_DIR}/servers"

# Source wizard modules
source_wizards() {
    for wizard in "${WIZARDS_DIR}"/*.sh; do
        if [ -f "$wizard" ]; then
            source "$wizard"
        fi
    done
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     🎮 ArcadeNode Game Server Deployment Wizard 🎮           ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_menu_item() {
    local num=$1
    local icon=$2
    local name=$3
    local desc=$4
    
    echo -e "  ${WHITE}${num})${NC} ${icon} ${BOLD}${name}${NC}"
    echo -e "     ${DIM}${desc}${NC}"
    echo ""
}

show_main_menu() {
    print_banner
    
    echo -e "${BOLD}Select a game server to deploy:${NC}"
    echo ""
    
    print_menu_item "1" "⛏️ " "Minecraft Java Edition" "Paper/Vanilla/Spigot server with plugin support"
    print_menu_item "2" "🪨" "Minecraft Bedrock Edition" "Official Bedrock Dedicated Server for cross-play"
    print_menu_item "3" "🧟" "Project Zomboid" "Multiplayer survival horror server"
    print_menu_item "4" "🎖️ " "Arma Reforger" "Military simulation dedicated server"
    
    echo -e "  ${WHITE}5)${NC} 📋 List running servers"
    echo -e "  ${WHITE}6)${NC} 🔧 Manage existing server"
    echo -e "  ${WHITE}0)${NC} ❌ Exit"
    echo ""
    
    read -p "Enter your choice [0-6]: " choice
    
    case $choice in
        1) deploy_minecraft_java ;;
        2) deploy_minecraft_bedrock ;;
        3) deploy_project_zomboid ;;
        4) deploy_arma_reforger ;;
        5) list_servers ;;
        6) manage_server ;;
        0) exit 0 ;;
        *) 
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            show_main_menu
            ;;
    esac
}

# Common functions
prompt_input() {
    local prompt=$1
    local default=$2
    local var_name=$3
    
    if [ -n "$default" ]; then
        read -p "${prompt} [${default}]: " value
        value="${value:-$default}"
    else
        read -p "${prompt}: " value
    fi
    
    eval "$var_name=\"$value\""
}

prompt_password() {
    local prompt=$1
    local var_name=$2
    
    read -s -p "${prompt}: " value
    echo ""
    
    eval "$var_name=\"$value\""
}

prompt_yes_no() {
    local prompt=$1
    local default=${2:-y}
    
    if [ "$default" = "y" ]; then
        read -p "${prompt} [Y/n]: " -n 1 -r
    else
        read -p "${prompt} [y/N]: " -n 1 -r
    fi
    echo ""
    
    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

generate_container_name() {
    local game_type=$1
    local server_name=$2
    
    # Convert to lowercase, replace spaces with hyphens
    local clean_name=$(echo "$server_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    echo "${game_type}-${clean_name}"
}

check_port_available() {
    local port=$1
    
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while ! check_port_available $port && [ $port -lt $((start_port + 100)) ]; do
        ((port++))
    done
    
    echo $port
}

create_server_directory() {
    local container_name=$1
    local server_dir="${SERVERS_DIR}/${container_name}"
    
    mkdir -p "${server_dir}/data"
    mkdir -p "${server_dir}/config"
    mkdir -p "${server_dir}/logs"
    
    echo "$server_dir"
}

show_deployment_summary() {
    local container_name=$1
    local game_type=$2
    local ports=$3
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}           🎉 Server Deployed Successfully! 🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Container:${NC} ${container_name}"
    echo -e "  ${CYAN}Game:${NC} ${game_type}"
    echo -e "  ${CYAN}Ports:${NC} ${ports}"
    echo -e "  ${CYAN}Status:${NC} $(docker inspect -f '{{.State.Status}}' ${container_name} 2>/dev/null || echo 'unknown')"
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo "  • View logs:    docker logs -f ${container_name}"
    echo "  • Stop server:  docker stop ${container_name}"
    echo "  • Start server: docker start ${container_name}"
    echo "  • Console:      docker attach ${container_name}"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

list_servers() {
    print_banner
    echo -e "${BOLD}Running Game Servers:${NC}"
    echo ""
    
    docker ps --filter "name=minecraft-" --filter "name=pz-" --filter "name=reforger-" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No servers running"
    
    echo ""
    echo -e "${BOLD}Stopped Game Servers:${NC}"
    echo ""
    
    docker ps -a --filter "status=exited" --filter "name=minecraft-" --filter "name=pz-" --filter "name=reforger-" \
        --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "No stopped servers"
    
    echo ""
    read -p "Press Enter to continue..."
    show_main_menu
}

manage_server() {
    print_banner
    echo -e "${BOLD}Select a server to manage:${NC}"
    echo ""
    
    # Get list of game server containers
    local containers=($(docker ps -a --filter "name=minecraft-" --filter "name=pz-" --filter "name=reforger-" --format "{{.Names}}" 2>/dev/null))
    
    if [ ${#containers[@]} -eq 0 ]; then
        echo "No game servers found."
        echo ""
        read -p "Press Enter to continue..."
        show_main_menu
        return
    fi
    
    local i=1
    for container in "${containers[@]}"; do
        local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        echo "  ${i}) ${container} [${status}]"
        ((i++))
    done
    echo "  0) Back to main menu"
    echo ""
    
    read -p "Select server: " selection
    
    if [ "$selection" = "0" ]; then
        show_main_menu
        return
    fi
    
    local index=$((selection - 1))
    if [ $index -ge 0 ] && [ $index -lt ${#containers[@]} ]; then
        manage_single_server "${containers[$index]}"
    else
        echo -e "${RED}Invalid selection${NC}"
        sleep 1
        manage_server
    fi
}

manage_single_server() {
    local container=$1
    
    print_banner
    echo -e "${BOLD}Managing: ${CYAN}${container}${NC}"
    echo ""
    
    local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
    echo -e "Status: ${status}"
    echo ""
    
    echo "  1) View logs"
    echo "  2) Start server"
    echo "  3) Stop server"
    echo "  4) Restart server"
    echo "  5) Delete server"
    echo "  6) View configuration"
    echo "  0) Back"
    echo ""
    
    read -p "Select action: " action
    
    case $action in
        1) 
            echo "Press Ctrl+C to exit logs..."
            sleep 1
            docker logs -f --tail 100 "$container"
            ;;
        2)
            docker start "$container"
            echo -e "${GREEN}Server started${NC}"
            sleep 2
            ;;
        3)
            docker stop "$container"
            echo -e "${YELLOW}Server stopped${NC}"
            sleep 2
            ;;
        4)
            docker restart "$container"
            echo -e "${GREEN}Server restarted${NC}"
            sleep 2
            ;;
        5)
            if prompt_yes_no "Are you sure you want to delete this server?" "n"; then
                docker rm -f "$container"
                echo -e "${RED}Server deleted${NC}"
                sleep 2
                show_main_menu
                return
            fi
            ;;
        6)
            docker inspect "$container" | less
            ;;
        0)
            show_main_menu
            return
            ;;
    esac
    
    manage_single_server "$container"
}

# Load game-specific wizard modules
source "${WIZARDS_DIR}/minecraft-java.sh" 2>/dev/null || true
source "${WIZARDS_DIR}/minecraft-bedrock.sh" 2>/dev/null || true
source "${WIZARDS_DIR}/project-zomboid.sh" 2>/dev/null || true
source "${WIZARDS_DIR}/arma-reforger.sh" 2>/dev/null || true

# Fallback deployments if wizards not loaded
deploy_minecraft_java() {
    if ! type _deploy_minecraft_java &>/dev/null; then
        source "${WIZARDS_DIR}/minecraft-java.sh"
    fi
    _deploy_minecraft_java
    show_main_menu
}

deploy_minecraft_bedrock() {
    if ! type _deploy_minecraft_bedrock &>/dev/null; then
        source "${WIZARDS_DIR}/minecraft-bedrock.sh"
    fi
    _deploy_minecraft_bedrock
    show_main_menu
}

deploy_project_zomboid() {
    if ! type _deploy_project_zomboid &>/dev/null; then
        source "${WIZARDS_DIR}/project-zomboid.sh"
    fi
    _deploy_project_zomboid
    show_main_menu
}

deploy_arma_reforger() {
    if ! type _deploy_arma_reforger &>/dev/null; then
        source "${WIZARDS_DIR}/arma-reforger.sh"
    fi
    _deploy_arma_reforger
    show_main_menu
}

# Entry point
main() {
    # Create wizards directory if needed
    mkdir -p "${WIZARDS_DIR}"
    mkdir -p "${SERVERS_DIR}"
    
    show_main_menu
}

main
