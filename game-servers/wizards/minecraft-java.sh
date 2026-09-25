#!/bin/bash
# Minecraft Java Edition Deployment Wizard

_deploy_minecraft_java() {
    print_banner
    echo -e "${BOLD}⛏️  Minecraft Java Edition Server Setup${NC}"
    echo -e "${DIM}Paper/Vanilla/Spigot server with plugin support${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if image exists
    if ! docker image inspect arcadenode/minecraft:latest &>/dev/null; then
        echo -e "${YELLOW}Minecraft image not found. Building...${NC}"
        docker build -t arcadenode/minecraft:latest "${SCRIPT_DIR}/game-servers/minecraft"
    fi

    echo -e "${CYAN}Step 1: Basic Configuration${NC}"
    echo ""

    # Server name
    prompt_input "Server name" "My Minecraft Server" SERVER_NAME
    
    # Container name
    local default_container=$(generate_container_name "minecraft" "$SERVER_NAME")
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
    echo -e "${CYAN}Step 2: Server Type${NC}"
    echo ""
    echo "  1) Paper (recommended - best performance + plugins)"
    echo "  2) Vanilla (official Mojang server)"
    echo "  3) Spigot (plugins, requires BuildTools)"
    echo ""
    read -p "Select server type [1]: " server_type_choice
    
    case ${server_type_choice:-1} in
        1) SERVER_TYPE="paper" ;;
        2) SERVER_TYPE="vanilla" ;;
        3) SERVER_TYPE="spigot" ;;
        *) SERVER_TYPE="paper" ;;
    esac

    # Minecraft version
    echo ""
    prompt_input "Minecraft version" "1.21.1" MC_VERSION

    echo ""
    echo -e "${CYAN}Step 3: Server Settings${NC}"
    echo ""

    prompt_input "Max players" "20" MAX_PLAYERS
    prompt_input "MOTD (Message of the Day)" "A Minecraft Server" MOTD
    
    echo ""
    echo "Game modes: survival, creative, adventure, spectator"
    prompt_input "Default gamemode" "survival" GAMEMODE
    
    echo ""
    echo "Difficulties: peaceful, easy, normal, hard"
    prompt_input "Difficulty" "normal" DIFFICULTY
    
    prompt_input "View distance (chunks)" "10" VIEW_DISTANCE
    
    if prompt_yes_no "Enable online mode (Mojang authentication)?" "y"; then
        ONLINE_MODE="true"
    else
        ONLINE_MODE="false"
    fi

    echo ""
    echo -e "${CYAN}Step 4: Memory & Performance${NC}"
    echo ""

    prompt_input "Maximum RAM" "2G" MAX_RAM
    prompt_input "Minimum RAM" "1G" MIN_RAM

    echo ""
    echo -e "${CYAN}Step 5: Network Configuration${NC}"
    echo ""

    local default_port=$(find_available_port 25565)
    prompt_input "Game port" "$default_port" GAME_PORT
    
    local default_rcon=$(find_available_port 25575)
    prompt_input "RCON port" "$default_rcon" RCON_PORT
    
    if prompt_yes_no "Enable RCON (remote console)?" "y"; then
        ENABLE_RCON="true"
        prompt_password "RCON password" RCON_PASSWORD
        if [ -z "$RCON_PASSWORD" ]; then
            RCON_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
            echo -e "Generated RCON password: ${CYAN}${RCON_PASSWORD}${NC}"
        fi
    else
        ENABLE_RCON="false"
        RCON_PASSWORD=""
    fi

    echo ""
    echo -e "${CYAN}Step 6: Operators (Optional)${NC}"
    echo ""
    prompt_input "Operator usernames (comma-separated)" "" OPS

    echo ""
    echo -e "${CYAN}Step 7: World Settings${NC}"
    echo ""

    prompt_input "Level name" "world" LEVEL_NAME
    prompt_input "World seed (leave empty for random)" "" LEVEL_SEED
    
    echo ""
    echo "World types: default, flat, largeBiomes, amplified"
    prompt_input "Level type" "default" LEVEL_TYPE

    # Create server directory
    local server_dir=$(create_server_directory "$CONTAINER_NAME")

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Configuration Summary:${NC}"
    echo ""
    echo -e "  Server Name:    ${WHITE}${SERVER_NAME}${NC}"
    echo -e "  Server Type:    ${WHITE}${SERVER_TYPE}${NC}"
    echo -e "  Version:        ${WHITE}${MC_VERSION}${NC}"
    echo -e "  Max Players:    ${WHITE}${MAX_PLAYERS}${NC}"
    echo -e "  Gamemode:       ${WHITE}${GAMEMODE}${NC}"
    echo -e "  Memory:         ${WHITE}${MIN_RAM} - ${MAX_RAM}${NC}"
    echo -e "  Game Port:      ${WHITE}${GAME_PORT}${NC}"
    echo -e "  RCON Port:      ${WHITE}${RCON_PORT}${NC}"
    echo -e "  Data Directory: ${WHITE}${server_dir}${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! prompt_yes_no "Deploy this server?" "y"; then
        echo "Deployment cancelled."
        return
    fi

    echo ""
    echo -e "${BLUE}Deploying Minecraft server...${NC}"
    
    # Build docker run command
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${GAME_PORT}:25565" \
        -p "${GAME_PORT}:25565/udp" \
        -p "${RCON_PORT}:25575" \
        -v "${server_dir}/data:/home/minecraft/data" \
        -v "${server_dir}/config:/home/minecraft/plugins" \
        -e "SERVER_TYPE=${SERVER_TYPE}" \
        -e "MC_VERSION=${MC_VERSION}" \
        -e "SERVER_NAME=${SERVER_NAME}" \
        -e "MOTD=${MOTD}" \
        -e "MAX_PLAYERS=${MAX_PLAYERS}" \
        -e "GAMEMODE=${GAMEMODE}" \
        -e "DIFFICULTY=${DIFFICULTY}" \
        -e "VIEW_DISTANCE=${VIEW_DISTANCE}" \
        -e "ONLINE_MODE=${ONLINE_MODE}" \
        -e "MAX_RAM=${MAX_RAM}" \
        -e "MIN_RAM=${MIN_RAM}" \
        -e "ENABLE_RCON=${ENABLE_RCON}" \
        -e "RCON_PASSWORD=${RCON_PASSWORD}" \
        -e "OPS=${OPS}" \
        -e "LEVEL_NAME=${LEVEL_NAME}" \
        -e "LEVEL_SEED=${LEVEL_SEED}" \
        -e "LEVEL_TYPE=${LEVEL_TYPE}" \
        --network arcadenode \
        arcadenode/minecraft:latest

    if [ $? -eq 0 ]; then
        # Save configuration
        cat > "${server_dir}/config/deployment.json" << EOF
{
    "container_name": "${CONTAINER_NAME}",
    "game": "minecraft-java",
    "server_type": "${SERVER_TYPE}",
    "version": "${MC_VERSION}",
    "server_name": "${SERVER_NAME}",
    "max_players": ${MAX_PLAYERS},
    "game_port": ${GAME_PORT},
    "rcon_port": ${RCON_PORT},
    "deployed_at": "$(date -Iseconds)"
}
EOF
        show_deployment_summary "$CONTAINER_NAME" "Minecraft Java Edition (${SERVER_TYPE})" "${GAME_PORT}/tcp, ${RCON_PORT}/tcp"
        
        echo ""
        echo -e "${CYAN}Server is starting... View logs with:${NC}"
        echo "  docker logs -f ${CONTAINER_NAME}"
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
