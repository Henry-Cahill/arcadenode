#!/bin/bash
# Project Zomboid Deployment Wizard

_deploy_project_zomboid() {
    print_banner
    echo -e "${BOLD}🧟 Project Zomboid Dedicated Server Setup${NC}"
    echo -e "${DIM}Multiplayer survival horror server${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo -e "${YELLOW}⚠️  Note: First startup will download ~3GB of game files via SteamCMD${NC}"
    echo ""

    # Check if image exists
    if ! docker image inspect arcadenode/project-zomboid:latest &>/dev/null; then
        echo -e "${YELLOW}Project Zomboid image not found. Building...${NC}"
        docker build -t arcadenode/project-zomboid:latest "${SCRIPT_DIR}/game-servers/project-zomboid"
    fi

    echo -e "${CYAN}Step 1: Basic Configuration${NC}"
    echo ""

    # Server name
    prompt_input "Server name" "ArcadeNode PZ Server" SERVER_NAME
    
    # Container name
    local default_container=$(generate_container_name "pz" "$SERVER_NAME")
    prompt_input "Container name" "$default_container" CONTAINER_NAME
    
    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Container '${CONTAINER_NAME}' already exists!${NC}"
        if prompt_yes_no "Remove existing container?" "n"; then
            docker rm -f "$CONTAINER_NAME"
        else
            return
        fi
    fi

    echo ""
    echo -e "${CYAN}Step 2: Server Passwords${NC}"
    echo ""

    prompt_password "Server password (leave empty for public)" SERVER_PASSWORD
    echo ""
    prompt_password "Admin password (required)" ADMIN_PASSWORD
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
        echo -e "Generated admin password: ${CYAN}${ADMIN_PASSWORD}${NC}"
    fi

    echo ""
    echo -e "${CYAN}Step 3: Server Settings${NC}"
    echo ""

    prompt_input "Max players" "16" MAX_PLAYERS
    prompt_input "Max RAM (MB)" "4096" MAX_RAM
    
    if prompt_yes_no "Enable PvP?" "y"; then
        PVP="true"
    else
        PVP="false"
    fi
    
    if prompt_yes_no "Pause server when empty?" "y"; then
        PAUSE_EMPTY="true"
    else
        PAUSE_EMPTY="false"
    fi

    echo ""
    echo -e "${CYAN}Step 4: Map Configuration${NC}"
    echo ""
    
    echo "Default maps: Muldraugh, KY; Riverside, KY; Rosewood, KY; West Point, KY"
    prompt_input "Map name" "Muldraugh, KY" MAP

    echo ""
    echo -e "${CYAN}Step 5: Network Configuration${NC}"
    echo ""

    local default_port=$(find_available_port 16261)
    prompt_input "Game port (UDP)" "$default_port" GAME_PORT
    
    local default_direct=$((GAME_PORT + 1))
    prompt_input "Direct connection port (UDP)" "$default_direct" DIRECT_PORT
    
    local default_rcon=$(find_available_port 27015)
    prompt_input "RCON port (TCP)" "$default_rcon" RCON_PORT

    echo ""
    echo -e "${CYAN}Step 6: Steam Workshop Mods (Optional)${NC}"
    echo ""
    
    echo "Enter Steam Workshop IDs for mods (comma-separated)"
    echo -e "${DIM}Find mods at: https://steamcommunity.com/app/108600/workshop/${NC}"
    prompt_input "Workshop IDs" "" WORKSHOP_IDS
    
    if [ -n "$WORKSHOP_IDS" ]; then
        echo ""
        echo "Enter corresponding Mod IDs (comma-separated, in same order)"
        echo -e "${DIM}Usually found in mod description or mod.info file${NC}"
        prompt_input "Mod IDs" "" MOD_IDS
    else
        MOD_IDS=""
    fi

    echo ""
    echo -e "${CYAN}Step 7: Zombie Settings${NC}"
    echo ""
    
    echo "Zombie spawn rates:"
    echo "  1) Insane (4.0x)"
    echo "  2) Very High (3.0x)"
    echo "  3) High (2.0x)"
    echo "  4) Normal (1.0x)"
    echo "  5) Low (0.5x)"
    echo "  6) Very Low (0.25x)"
    echo "  7) None (0)"
    echo ""
    read -p "Select zombie population [4]: " zombie_choice
    
    case ${zombie_choice:-4} in
        1) ZOMBIE_COUNT="4.0" ;;
        2) ZOMBIE_COUNT="3.0" ;;
        3) ZOMBIE_COUNT="2.0" ;;
        4) ZOMBIE_COUNT="1.0" ;;
        5) ZOMBIE_COUNT="0.5" ;;
        6) ZOMBIE_COUNT="0.25" ;;
        7) ZOMBIE_COUNT="0" ;;
        *) ZOMBIE_COUNT="1.0" ;;
    esac

    # Create server directory
    local server_dir=$(create_server_directory "$CONTAINER_NAME")

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Configuration Summary:${NC}"
    echo ""
    echo -e "  Server Name:     ${WHITE}${SERVER_NAME}${NC}"
    echo -e "  Max Players:     ${WHITE}${MAX_PLAYERS}${NC}"
    echo -e "  Max RAM:         ${WHITE}${MAX_RAM}MB${NC}"
    echo -e "  Map:             ${WHITE}${MAP}${NC}"
    echo -e "  PvP:             ${WHITE}${PVP}${NC}"
    echo -e "  Zombie Count:    ${WHITE}${ZOMBIE_COUNT}x${NC}"
    echo -e "  Game Port:       ${WHITE}${GAME_PORT}/udp${NC}"
    echo -e "  RCON Port:       ${WHITE}${RCON_PORT}/tcp${NC}"
    echo -e "  Admin Password:  ${WHITE}${ADMIN_PASSWORD}${NC}"
    if [ -n "$WORKSHOP_IDS" ]; then
        echo -e "  Workshop Mods:   ${WHITE}${WORKSHOP_IDS}${NC}"
    fi
    echo -e "  Data Directory:  ${WHITE}${server_dir}${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  First startup: ~10-15 minutes (downloading game files)${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! prompt_yes_no "Deploy this server?" "y"; then
        echo "Deployment cancelled."
        return
    fi

    echo ""
    echo -e "${BLUE}Deploying Project Zomboid server...${NC}"
    
    # Build docker run command
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${GAME_PORT}:16261/udp" \
        -p "${DIRECT_PORT}:16262/udp" \
        -p "${RCON_PORT}:27015/tcp" \
        -v "${server_dir}/data:/home/pzserver/data" \
        -e "SERVER_NAME=${SERVER_NAME}" \
        -e "SERVER_PASSWORD=${SERVER_PASSWORD}" \
        -e "ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
        -e "MAX_PLAYERS=${MAX_PLAYERS}" \
        -e "MAX_RAM=${MAX_RAM}" \
        -e "PVP=${PVP}" \
        -e "PAUSE_EMPTY=${PAUSE_EMPTY}" \
        -e "MAP=${MAP}" \
        -e "MOD_IDS=${MOD_IDS}" \
        -e "WORKSHOP_IDS=${WORKSHOP_IDS}" \
        -e "ZOMBIE_COUNT=${ZOMBIE_COUNT}" \
        --network arcadenode \
        arcadenode/project-zomboid:latest

    if [ $? -eq 0 ]; then
        # Save configuration
        cat > "${server_dir}/config/deployment.json" << EOF
{
    "container_name": "${CONTAINER_NAME}",
    "game": "project-zomboid",
    "server_name": "${SERVER_NAME}",
    "max_players": ${MAX_PLAYERS},
    "game_port": ${GAME_PORT},
    "direct_port": ${DIRECT_PORT},
    "rcon_port": ${RCON_PORT},
    "map": "${MAP}",
    "deployed_at": "$(date -Iseconds)"
}
EOF
        show_deployment_summary "$CONTAINER_NAME" "Project Zomboid" "${GAME_PORT}/udp, ${DIRECT_PORT}/udp, ${RCON_PORT}/tcp"
        
        echo ""
        echo -e "${YELLOW}Server is downloading game files via SteamCMD...${NC}"
        echo -e "${DIM}This may take 10-15 minutes on first run.${NC}"
        echo ""
        
        if prompt_yes_no "View startup logs now?" "y"; then
            echo "Press Ctrl+C to exit logs..."
            sleep 2
            docker logs -f "$CONTAINER_NAME"
        fi
    else
        echo -e "${RED}Failed to deploy server${NC}"
    fi

    echo ""
    read -p "Press Enter to continue..."
}
