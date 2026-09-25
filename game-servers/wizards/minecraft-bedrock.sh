#!/bin/bash
# Minecraft Bedrock Edition Deployment Wizard

_deploy_minecraft_bedrock() {
    print_banner
    echo -e "${BOLD}🪨 Minecraft Bedrock Edition Server Setup${NC}"
    echo -e "${DIM}Official Bedrock Dedicated Server for cross-play${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if image exists
    if ! docker image inspect arcadenode/minecraft-bedrock:latest &>/dev/null; then
        echo -e "${YELLOW}Minecraft Bedrock image not found. Building...${NC}"
        docker build -t arcadenode/minecraft-bedrock:latest "${SCRIPT_DIR}/game-servers/minecraft-bedrock"
    fi

    echo -e "${CYAN}Step 1: Basic Configuration${NC}"
    echo ""

    # Server name
    prompt_input "Server name" "Bedrock Server" SERVER_NAME
    
    # Container name
    local default_container=$(generate_container_name "bedrock" "$SERVER_NAME")
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
    echo -e "${CYAN}Step 2: Version Selection${NC}"
    echo ""
    echo "Enter 'LATEST' for the latest version or a specific version (e.g., 1.21.44.01)"
    prompt_input "Server version" "LATEST" VERSION

    echo ""
    echo -e "${CYAN}Step 3: Server Settings${NC}"
    echo ""

    prompt_input "Max players" "10" MAX_PLAYERS
    
    echo ""
    echo "Game modes: survival, creative, adventure"
    prompt_input "Default gamemode" "survival" GAMEMODE
    
    echo ""
    echo "Difficulties: peaceful, easy, normal, hard"
    prompt_input "Difficulty" "normal" DIFFICULTY
    
    prompt_input "View distance (chunks, 5-32)" "32" VIEW_DISTANCE
    prompt_input "Tick distance (4-12)" "4" TICK_DISTANCE
    
    if prompt_yes_no "Enable Xbox Live authentication?" "y"; then
        ONLINE_MODE="true"
    else
        ONLINE_MODE="false"
    fi

    echo ""
    echo -e "${CYAN}Step 4: World Configuration${NC}"
    echo ""

    prompt_input "Level name" "Bedrock level" LEVEL_NAME
    prompt_input "World seed (leave empty for random)" "" LEVEL_SEED

    echo ""
    echo -e "${CYAN}Step 5: Network Configuration${NC}"
    echo ""

    local default_port=$(find_available_port 19132)
    prompt_input "Game port (IPv4)" "$default_port" GAME_PORT
    
    local default_port6=$((GAME_PORT + 1))
    prompt_input "Game port (IPv6)" "$default_port6" GAME_PORT6

    echo ""
    echo -e "${CYAN}Step 6: Anti-Cheat Settings${NC}"
    echo ""
    echo "Server authoritative movement modes:"
    echo "  1) server-auth (recommended - server validates all movement)"
    echo "  2) client-auth (trust client - less secure)"
    echo "  3) server-auth-with-rewind (strictest - may cause rubber-banding)"
    echo ""
    read -p "Select mode [1]: " auth_choice
    
    case ${auth_choice:-1} in
        1) SERVER_AUTH_MOVEMENT="server-auth" ;;
        2) SERVER_AUTH_MOVEMENT="client-auth" ;;
        3) SERVER_AUTH_MOVEMENT="server-auth-with-rewind" ;;
        *) SERVER_AUTH_MOVEMENT="server-auth" ;;
    esac

    echo ""
    echo -e "${CYAN}Step 7: Allowlist & Operators (Optional)${NC}"
    echo ""
    
    if prompt_yes_no "Enable allowlist (whitelist)?" "n"; then
        WHITE_LIST="true"
        echo "Enter Xbox Gamertags for allowlist (comma-separated):"
        prompt_input "Allowed players" "" ALLOW_LIST_USERS
    else
        WHITE_LIST="false"
        ALLOW_LIST_USERS=""
    fi
    
    echo ""
    echo "Enter XUIDs for operators (comma-separated)."
    echo -e "${DIM}Find XUIDs at: https://www.cxkes.me/xbox/xuid${NC}"
    prompt_input "Operator XUIDs" "" OPS

    # Create server directory
    local server_dir=$(create_server_directory "$CONTAINER_NAME")

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Configuration Summary:${NC}"
    echo ""
    echo -e "  Server Name:    ${WHITE}${SERVER_NAME}${NC}"
    echo -e "  Version:        ${WHITE}${VERSION}${NC}"
    echo -e "  Max Players:    ${WHITE}${MAX_PLAYERS}${NC}"
    echo -e "  Gamemode:       ${WHITE}${GAMEMODE}${NC}"
    echo -e "  Difficulty:     ${WHITE}${DIFFICULTY}${NC}"
    echo -e "  Xbox Auth:      ${WHITE}${ONLINE_MODE}${NC}"
    echo -e "  Game Port:      ${WHITE}${GAME_PORT}/udp${NC}"
    echo -e "  Anti-Cheat:     ${WHITE}${SERVER_AUTH_MOVEMENT}${NC}"
    echo -e "  Data Directory: ${WHITE}${server_dir}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! prompt_yes_no "Deploy this server?" "y"; then
        echo "Deployment cancelled."
        return
    fi

    echo ""
    echo -e "${BLUE}Deploying Minecraft Bedrock server...${NC}"
    
    # Build docker run command
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${GAME_PORT}:19132/udp" \
        -p "${GAME_PORT6}:19133/udp" \
        -v "${server_dir}/data:/home/bedrock/data" \
        -e "VERSION=${VERSION}" \
        -e "SERVER_NAME=${SERVER_NAME}" \
        -e "MAX_PLAYERS=${MAX_PLAYERS}" \
        -e "GAMEMODE=${GAMEMODE}" \
        -e "DIFFICULTY=${DIFFICULTY}" \
        -e "VIEW_DISTANCE=${VIEW_DISTANCE}" \
        -e "TICK_DISTANCE=${TICK_DISTANCE}" \
        -e "ONLINE_MODE=${ONLINE_MODE}" \
        -e "LEVEL_NAME=${LEVEL_NAME}" \
        -e "LEVEL_SEED=${LEVEL_SEED}" \
        -e "WHITE_LIST=${WHITE_LIST}" \
        -e "ALLOW_LIST_USERS=${ALLOW_LIST_USERS}" \
        -e "OPS=${OPS}" \
        -e "SERVER_AUTHORITATIVE_MOVEMENT=${SERVER_AUTH_MOVEMENT}" \
        --network arcadenode \
        arcadenode/minecraft-bedrock:latest

    if [ $? -eq 0 ]; then
        # Save configuration
        cat > "${server_dir}/config/deployment.json" << EOF
{
    "container_name": "${CONTAINER_NAME}",
    "game": "minecraft-bedrock",
    "version": "${VERSION}",
    "server_name": "${SERVER_NAME}",
    "max_players": ${MAX_PLAYERS},
    "game_port": ${GAME_PORT},
    "game_port_v6": ${GAME_PORT6},
    "deployed_at": "$(date -Iseconds)"
}
EOF
        show_deployment_summary "$CONTAINER_NAME" "Minecraft Bedrock Edition" "${GAME_PORT}/udp, ${GAME_PORT6}/udp"
        
        echo ""
        echo -e "${CYAN}Server is downloading and starting...${NC}"
        echo -e "${DIM}First startup may take a few minutes to download the server.${NC}"
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
