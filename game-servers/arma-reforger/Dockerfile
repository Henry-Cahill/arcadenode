# Arma Reforger Dedicated Server
# ArcadeNode Game Server Cartridge

FROM steamcmd/steamcmd:ubuntu-24

LABEL maintainer="ArcadeNode"
LABEL game="Arma Reforger"
LABEL version="1.0"

# Environment variables
ENV STEAM_APP_ID=1874900
ENV SERVER_NAME="ArcadeNode Reforger Server"
ENV SERVER_PASSWORD=""
ENV ADMIN_PASSWORD="changeme"
ENV GAME_PORT=2001
ENV STEAM_QUERY_PORT=17777
ENV A2S_PORT=17777
ENV MAX_PLAYERS=64
ENV VISIBLE=true
ENV CROSSPLATFORM=true
ENV BATTLYE=true
ENV SCENARIO_ID=""{ECC61978EDCC2B5A}Missions/23_Campaign.conf""
ENV GAME_MODE=""
ENV SERVER_MAX_VIEW_DISTANCE=2500
ENV SERVER_MIN_GRASS_DISTANCE=50
ENV NETWORK_VIEW_DISTANCE=1500
ENV MODS=""

# Install dependencies
RUN apt-get update && apt-get install -y \
    lib32gcc-s1 \
    libcurl4 \
    curl \
    jq \
    netcat-openbsd \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create server user and directories
RUN useradd -m -s /bin/bash reforger \
    && mkdir -p /home/reforger/server \
    && mkdir -p /home/reforger/data/profile \
    && mkdir -p /home/reforger/data/addons \
    && mkdir -p /home/reforger/data/configs \
    && chown -R reforger:reforger /home/reforger

# Switch to server user
USER reforger
WORKDIR /home/reforger

# Copy configuration files
COPY --chown=reforger:reforger entrypoint.sh /home/reforger/entrypoint.sh
COPY --chown=reforger:reforger config.json.template /home/reforger/config.json.template
RUN chmod +x /home/reforger/entrypoint.sh

# Expose ports
# Game port (UDP)
EXPOSE 2001/udp
# Steam Query port (UDP)
EXPOSE 17777/udp

# Volumes for persistence
VOLUME ["/home/reforger/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD netcat -zu localhost ${GAME_PORT} || exit 1

ENTRYPOINT ["/home/reforger/entrypoint.sh"]
