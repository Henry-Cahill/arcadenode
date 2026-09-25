# Project Zomboid Dedicated Server
# ArcadeNode Game Server Cartridge

FROM steamcmd/steamcmd:ubuntu-24

LABEL maintainer="ArcadeNode"
LABEL game="Project Zomboid"
LABEL version="1.0"

# Environment variables
ENV STEAM_APP_ID=380870
ENV SERVER_NAME="ArcadeNode_PZ_Server"
ENV SERVER_PASSWORD=""
ENV ADMIN_PASSWORD="changeme"
ENV SERVER_PORT=16261
ENV DIRECT_PORT=16262
ENV RCON_PORT=27015
ENV MAX_PLAYERS=16
ENV MAX_RAM=4096
ENV PUBLIC_SERVER=true
ENV PAUSE_EMPTY=true
ENV STEAM_VAC=true
ENV MOD_IDS=""
ENV WORKSHOP_IDS=""
ENV BETA_BRANCH=""
ENV BETA_PASSWORD=""
ENV HOME=/home/pzserver

# Install dependencies
RUN apt-get update && apt-get install -y \
    lib32gcc-s1 \
    libsdl2-2.0-0 \
    curl \
    jq \
    netcat-openbsd \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create directories and set permissions
# .cache is for server-generated configs, scripts, and logs
RUN mkdir -p /home/pzserver/server \
    && mkdir -p /home/pzserver/data \
    && mkdir -p /home/pzserver/Zomboid \
    && mkdir -p /home/pzserver/.steam \
    && mkdir -p /home/pzserver/.cache/configs \
    && mkdir -p /home/pzserver/.cache/scripts \
    && mkdir -p /home/pzserver/.cache/logs \
    && mkdir -p /home/pzserver/.cache/templates \
    && chmod -R 777 /home/pzserver

WORKDIR /home/pzserver

# Copy startup script
COPY entrypoint.sh /home/pzserver/entrypoint.sh
COPY server.ini.template /home/pzserver/server.ini.template
RUN chmod +x /home/pzserver/entrypoint.sh

# Expose ports
# Game port (UDP)
EXPOSE 16261/udp
# Direct connection port (UDP)  
EXPOSE 16262/udp
# RCON port (TCP)
EXPOSE 27015/tcp

# Volumes for persistence
VOLUME ["/home/pzserver/data"]

# Health check - use default port since ENV vars aren't expanded at runtime
# Increased start-period because PZ server takes a LONG time to initialize (map loading, etc.)
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=5 \
    CMD netcat -zu localhost 16261 || exit 1

ENTRYPOINT ["/home/pzserver/entrypoint.sh"]
