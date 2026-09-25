#!/bin/bash
# Arma Reforger Deployment Wizard

_deploy_arma_reforger() {
    print_banner
    echo -e "${BOLD}🎖️  Arma Reforger Dedicated Server Setup${NC}"
    echo -e "${DIM}Military simulation dedicated server${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo -e "${YELLOW}⚠️  Note: First startup will download ~7GB of game files via SteamCMD${NC}"
    echo ""

    # Check if image exists
    if ! docker image inspect arcadenode/arma-reforger:latest &>/dev/null; then
        echo -e "${YELLOW}Arma Reforger image not found. Building...${NC}"
        docker build -t arcadenode/arma-reforger:latest "${SCRIPT_DIR}/game-servers/arma-reforger"
    fi

    echo -e "${CYAN}Step 1: Basic Configuration${NC}"
    echo ""

    # Server name
    prompt_input "Server name" "ArcadeNode Reforger" SERVER_NAME
    
    # Container name
    local default_container=$(generate_container_name "reforger" "$SERVER_NAME")
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

    prompt_input "Max players" "64" MAX_PLAYERS
    prompt_input "Max FPS (server tick rate)" "60" SERVER_MAX_FPS

    echo ""
    echo -e "${CYAN}Step 4: Scenario Selection${NC}"
    echo ""
    
    echo "Available scenarios:"
    echo "  1) Conflict - Everon (default warfare mode)"
    echo "  2) Game Master - Everon (Zeus-like mode)"
    echo "  3) Game Master - Arland"
    echo "  4) Combat Ops - Everon"
    echo "  5) Custom (enter scenario ID manually)"
    echo ""
    read -p "Select scenario [1]: " scenario_choice
    
    case ${scenario_choice:-1} in
        1) SCENARIO_ID="{ECC61978EDCC2B5A}Missions/23_Campaign.conf" ;;
        2) SCENARIO_ID="{59AD59368755F41A}Missions/21_GM_Eden.conf" ;;
        3) SCENARIO_ID="{28802845ADA64D52}Missions/22_GM_Arland.conf" ;;
        4) SCENARIO_ID="{59AD59368755F41A}Missions/23_Campaign_Eden.conf" ;;
        5) 
            prompt_input "Custom scenario ID" "" SCENARIO_ID
            ;;
        *) SCENARIO_ID="{ECC61978EDCC2B5A}Missions/23_Campaign.conf" ;;
    esac

    echo ""
    echo -e "${CYAN}Step 5: Platform Settings${NC}"
    echo ""
    
    if prompt_yes_no "Enable crossplay (Xbox/PC)?" "y"; then
        CROSSPLATFORM="true"
    else
        CROSSPLATFORM="false"
    fi
    
    if prompt_yes_no "Enable BattlEye anti-cheat?" "y"; then
        BATTLYE="true"
    else
        BATTLYE="false"
    fi
    
    if prompt_yes_no "Disable third-person view?" "n"; then
        DISABLE_THIRD_PERSON="true"
    else
        DISABLE_THIRD_PERSON="false"
    fi

    echo ""
    echo -e "${CYAN}Step 6: Network Configuration${NC}"
    echo ""

    local default_port=$(find_available_port 2001)
    prompt_input "Game port (UDP)" "$default_port" GAME_PORT
    
    local default_query=$(find_available_port 17777)
    prompt_input "Steam Query port (UDP)" "$default_query" QUERY_PORT

    echo ""
    echo -e "${CYAN}Step 7: Mods (Optional)${NC}"
    echo ""
    
    echo "Enter mod IDs (comma-separated)"
    echo -e "${DIM}Find mods in Arma Reforger Workshop${NC}"
    prompt_input "Mod IDs" "" MODS

    echo ""
    echo -e "${CYAN}Step 8: Network Quality Settings${NC}"
    echo ""
    
    echo "Network quality presets:"
    echo "  1) High (recommended for good connections)"
    echo "  2) Medium"
    echo "  3) Low (for poor connections)"
    echo ""
    read -p "Select network quality [1]: " network_choice
    
    case ${network_choice:-1} in
        1) 
            NETWORK_VIEW_DISTANCE="2500"
            STREAMING_BUDGET="512"
            ;;
        2) 
            NETWORK_VIEW_DISTANCE="1500"
            STREAMING_BUDGET="256"
            ;;
        3) 
            NETWORK_VIEW_DISTANCE="1000"
            STREAMING_BUDGET="128"
            ;;
        *) 
            NETWORK_VIEW_DISTANCE="2500"
            STREAMING_BUDGET="512"
            ;;
    esac

    # Create server directory
    local server_dir=$(create_server_directory "$CONTAINER_NAME")

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Configuration Summary:${NC}"
    echo ""
    echo -e "  Server Name:     ${WHITE}${SERVER_NAME}${NC}"
    echo -e "  Max Players:     ${WHITE}${MAX_PLAYERS}${NC}"
    echo -e "  Scenario:        ${WHITE}${SCENARIO_ID}${NC}"
    echo -e "  Crossplay:       ${WHITE}${CROSSPLATFORM}${NC}"
    echo -e "  BattlEye:        ${WHITE}${BATTLYE}${NC}"
    echo -e "  Game Port:       ${WHITE}${GAME_PORT}/udp${NC}"
    echo -e "  Query Port:      ${WHITE}${QUERY_PORT}/udp${NC}"
    echo -e "  Admin Password:  ${WHITE}${ADMIN_PASSWORD}${NC}"
    if [ -n "$MODS" ]; then
        echo -e "  Mods:            ${WHITE}${MODS}${NC}"
    fi
    echo -e "  Data Directory:  ${WHITE}${server_dir}${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  First startup: ~15-20 minutes (downloading ~7GB game files)${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! prompt_yes_no "Deploy this server?" "y"; then
        echo "Deployment cancelled."
        return
    fi

    echo ""
    echo -e "${BLUE}Deploying Arma Reforger server...${NC}"
    
    # Build docker run command
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${GAME_PORT}:2001/udp" \
        -p "${QUERY_PORT}:17777/udp" \
        -v "${server_dir}/data:/home/reforger/data" \
        -e "SERVER_NAME=${SERVER_NAME}" \
        -e "SERVER_PASSWORD=${SERVER_PASSWORD}" \
        -e "ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
        -e "MAX_PLAYERS=${MAX_PLAYERS}" \
        -e "SCENARIO_ID=${SCENARIO_ID}" \
        -e "CROSSPLATFORM=${CROSSPLATFORM}" \
        -e "BATTLYE=${BATTLYE}" \
        -e "DISABLE_THIRD_PERSON=${DISABLE_THIRD_PERSON}" \
        -e "MODS=${MODS}" \
        -e "SERVER_MAX_FPS=${SERVER_MAX_FPS}" \
        -e "NETWORK_VIEW_DISTANCE=${NETWORK_VIEW_DISTANCE}" \
        -e "STREAMING_BUDGET=${STREAMING_BUDGET}" \
        --network arcadenode \
        arcadenode/arma-reforger:latest

    if [ $? -eq 0 ]; then
        # Save configuration
        cat > "${server_dir}/config/deployment.json" << EOF
{
    "container_name": "${CONTAINER_NAME}",
    "game": "arma-reforger",
    "server_name": "${SERVER_NAME}",
    "max_players": ${MAX_PLAYERS},
    "scenario": "${SCENARIO_ID}",
    "game_port": ${GAME_PORT},
    "query_port": ${QUERY_PORT},
    "crossplatform": ${CROSSPLATFORM},
    "battleye": ${BATTLYE},
    "deployed_at": "$(date -Iseconds)"
}
EOF
        show_deployment_summary "$CONTAINER_NAME" "Arma Reforger" "${GAME_PORT}/udp, ${QUERY_PORT}/udp"
        
        echo ""
        echo -e "${YELLOW}Server is downloading game files via SteamCMD...${NC}"
        echo -e "${DIM}This may take 15-20 minutes on first run (~7GB download).${NC}"
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
