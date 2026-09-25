#!/bin/bash
set -e

SERVER_DIR="/home/reforger/server"
DATA_DIR="/home/reforger/data"
STEAMCMD="/usr/games/steamcmd"

echo "=========================================="
echo "  ArcadeNode - Arma Reforger Server"
echo "=========================================="

# Install/Update Arma Reforger Dedicated Server
echo "[INFO] Checking for server updates..."
${STEAMCMD} +login anonymous \
    +force_install_dir ${SERVER_DIR} \
    +app_update ${STEAM_APP_ID} validate \
    +quit

# Create data directories
mkdir -p "${DATA_DIR}/profile"
mkdir -p "${DATA_DIR}/addons"
mkdir -p "${DATA_DIR}/configs"
mkdir -p "${DATA_DIR}/logs"

# Generate server configuration
CONFIG_FILE="${DATA_DIR}/configs/server.json"
echo "[INFO] Generating server configuration..."

# Parse MODS environment variable into JSON array
MODS_JSON="[]"
if [ -n "${MODS}" ]; then
    MODS_JSON=$(echo "${MODS}" | jq -R 'split(",") | map({modId: ., name: "", version: ""})')
fi

# Create the config file
cat > "${CONFIG_FILE}" << EOF
{
    "dedicatedServerId": "",
    "region": "EU",
    "gameHostBindAddress": "0.0.0.0",
    "gameHostBindPort": ${GAME_PORT},
    "gameHostRegisterBindAddress": "",
    "gameHostRegisterPort": ${GAME_PORT},
    "adminPassword": "${ADMIN_PASSWORD}",
    "game": {
        "name": "${SERVER_NAME}",
        "password": "${SERVER_PASSWORD}",
        "passwordAdmin": "${ADMIN_PASSWORD}",
        "admins": [],
        "scenarioId": ${SCENARIO_ID},
        "maxPlayers": ${MAX_PLAYERS},
        "visible": ${VISIBLE},
        "crossPlatform": ${CROSSPLATFORM},
        "supportedPlatforms": [
            "PLATFORM_PC",
            "PLATFORM_XBL"
        ],
        "gameProperties": {
            "serverMaxViewDistance": ${SERVER_MAX_VIEW_DISTANCE},
            "serverMinGrassDistance": ${SERVER_MIN_GRASS_DISTANCE},
            "networkViewDistance": ${NETWORK_VIEW_DISTANCE},
            "disableThirdPerson": false,
            "fastValidation": true,
            "battlEye": ${BATTLYE},
            "VONDisableUI": false,
            "VONDisableDirectSpeechUI": false,
            "missionHeader": {
                "m_iPlayerCount": ${MAX_PLAYERS},
                "m_eEditableGameFlags": 6,
                "m_eDefaultGameFlags": 6
            }
        },
        "mods": ${MODS_JSON}
    },
    "a2s": {
        "address": "0.0.0.0",
        "port": ${A2S_PORT}
    },
    "rpiServer": {
        "bindAddress": "0.0.0.0",
        "bindPort": 2002
    },
    "operating": {
        "lobbyPlayerSynchronise": true,
        "disableCrashReporter": false
    }
}
EOF

echo "[INFO] Starting Arma Reforger Server..."
echo "[INFO] Server Name: ${SERVER_NAME}"
echo "[INFO] Max Players: ${MAX_PLAYERS}"
echo "[INFO] Game Port: ${GAME_PORT}/udp"
echo "[INFO] Query Port: ${A2S_PORT}/udp"
echo "[INFO] BattlEye: ${BATTLYE}"
echo "[INFO] Cross Platform: ${CROSSPLATFORM}"

cd ${SERVER_DIR}

# Start the server
exec ./ArmaReforgerServer \
    -config "${CONFIG_FILE}" \
    -profile "${DATA_DIR}/profile" \
    -addonsDir "${DATA_DIR}/addons" \
    -logLevel normal \
    -logStats 60000 \
    "$@"
