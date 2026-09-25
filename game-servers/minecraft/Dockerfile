# Minecraft Server (Paper/Vanilla)
# ArcadeNode Game Server Cartridge

FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="ArcadeNode"
LABEL game="Minecraft"
LABEL version="1.0"

# Environment variables
ENV SERVER_TYPE=paper
ENV MC_VERSION=1.21.1
ENV PAPER_BUILD=latest
ENV SERVER_NAME="ArcadeNode MC Server"
ENV SERVER_PORT=25565
ENV RCON_PORT=25575
ENV RCON_PASSWORD="changeme"
ENV MAX_PLAYERS=20
ENV MOTD="ArcadeNode Minecraft Server"
ENV DIFFICULTY=normal
ENV GAMEMODE=survival
ENV LEVEL_NAME=world
ENV LEVEL_SEED=""
ENV LEVEL_TYPE=minecraft:normal
ENV MAX_WORLD_SIZE=29999984
ENV VIEW_DISTANCE=10
ENV SIMULATION_DISTANCE=10
ENV MAX_RAM=2G
ENV MIN_RAM=1G
ENV ONLINE_MODE=true
ENV WHITE_LIST=false
ENV ENFORCE_WHITELIST=false
ENV PVP=true
ENV ALLOW_NETHER=true
ENV ALLOW_FLIGHT=false
ENV SPAWN_PROTECTION=16
ENV SPAWN_ANIMALS=true
ENV SPAWN_MONSTERS=true
ENV SPAWN_NPCS=true
ENV GENERATE_STRUCTURES=true
ENV ENABLE_RCON=true
ENV ENABLE_QUERY=true
ENV ENABLE_COMMAND_BLOCK=false
ENV OPS=""
ENV ICON_URL=""

# Install dependencies
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    netcat-openbsd \
    wget

# Create server user and directories
RUN adduser -D -h /home/minecraft minecraft \
    && mkdir -p /home/minecraft/server \
    && mkdir -p /home/minecraft/data \
    && mkdir -p /home/minecraft/plugins \
    && chown -R minecraft:minecraft /home/minecraft

# Switch to server user
USER minecraft
WORKDIR /home/minecraft

# Copy configuration files
COPY --chown=minecraft:minecraft entrypoint.sh /home/minecraft/entrypoint.sh
COPY --chown=minecraft:minecraft server.properties.template /home/minecraft/server.properties.template
RUN chmod +x /home/minecraft/entrypoint.sh

# Expose ports
# Game port (TCP/UDP)
EXPOSE 25565/tcp
EXPOSE 25565/udp
# RCON port (TCP)
EXPOSE 25575/tcp
# Query port (UDP)
EXPOSE 25565/udp

# Volumes for persistence
VOLUME ["/home/minecraft/data"]
VOLUME ["/home/minecraft/plugins"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD echo "list" | nc -q 1 localhost ${RCON_PORT} || exit 1

ENTRYPOINT ["/home/minecraft/entrypoint.sh"]
