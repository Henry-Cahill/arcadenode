# Minecraft Bedrock Dedicated Server
# ArcadeNode Game Server Cartridge

FROM ubuntu:24.04

LABEL maintainer="ArcadeNode"
LABEL game="Minecraft Bedrock"
LABEL version="1.0"

# Environment variables
ENV SERVER_NAME="ArcadeNode Bedrock Server"
ENV GAMEMODE=survival
ENV DIFFICULTY=normal
ENV LEVEL_NAME="Bedrock level"
ENV LEVEL_SEED=""
ENV LEVEL_TYPE=DEFAULT
ENV MAX_PLAYERS=10
ENV SERVER_PORT=19132
ENV SERVER_PORTV6=19133
ENV ONLINE_MODE=true
ENV WHITE_LIST=false
ENV ALLOW_CHEATS=false
ENV VIEW_DISTANCE=32
ENV TICK_DISTANCE=4
ENV PLAYER_IDLE_TIMEOUT=30
ENV MAX_THREADS=8
ENV DEFAULT_PLAYER_PERMISSION_LEVEL=member
ENV TEXTUREPACK_REQUIRED=false
ENV CONTENT_LOG_FILE_ENABLED=false
ENV COMPRESSION_THRESHOLD=1
ENV COMPRESSION_ALGORITHM=zlib
ENV SERVER_AUTHORITATIVE_MOVEMENT=server-auth
ENV PLAYER_MOVEMENT_SCORE_THRESHOLD=20
ENV PLAYER_MOVEMENT_ACTION_DIRECTION_THRESHOLD=0.85
ENV PLAYER_MOVEMENT_DISTANCE_THRESHOLD=0.3
ENV PLAYER_MOVEMENT_DURATION_THRESHOLD_IN_MS=500
ENV CORRECT_PLAYER_MOVEMENT=false
ENV SERVER_AUTHORITATIVE_BLOCK_BREAKING=false
ENV CHAT_RESTRICTION=None
ENV DISABLE_PLAYER_INTERACTION=false
ENV CLIENT_SIDE_CHUNK_GENERATION_ENABLED=true
ENV BLOCK_NETWORK_IDS_ARE_HASHES=true
ENV DISABLE_PERSONA=false
ENV DISABLE_CUSTOM_SKINS=false
ENV SERVER_BUILD_RADIUS_RATIO=Disabled
ENV ALLOW_LIST_USERS=""
ENV OPS=""
ENV VERSION=LATEST

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    libcurl4 \
    libssl3 \
    netcat-openbsd \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Create server user and directories
RUN useradd -m -s /bin/bash bedrock \
    && mkdir -p /home/bedrock/server \
    && mkdir -p /home/bedrock/data/worlds \
    && mkdir -p /home/bedrock/data/resource_packs \
    && mkdir -p /home/bedrock/data/behavior_packs \
    && chown -R bedrock:bedrock /home/bedrock

# Switch to server user
USER bedrock
WORKDIR /home/bedrock

# Copy configuration files
COPY --chown=bedrock:bedrock entrypoint.sh /home/bedrock/entrypoint.sh
COPY --chown=bedrock:bedrock server.properties.template /home/bedrock/server.properties.template
RUN chmod +x /home/bedrock/entrypoint.sh

# Expose ports
# Game port IPv4 (UDP)
EXPOSE 19132/udp
# Game port IPv6 (UDP)
EXPOSE 19133/udp

# Volumes for persistence
VOLUME ["/home/bedrock/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD netcat -zu localhost ${SERVER_PORT} || exit 1

ENTRYPOINT ["/home/bedrock/entrypoint.sh"]
