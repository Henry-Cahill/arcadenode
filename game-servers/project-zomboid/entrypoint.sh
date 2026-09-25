#!/bin/bash
set -e

# =============================================================================
# ArcadeNode - Project Zomboid Server Entrypoint
# =============================================================================
# Directory structure:
#   /home/pzserver/server     - PZ server installation (from SteamCMD)
#   /home/pzserver/data       - Persistent data volume (mounted)
#   /home/pzserver/.cache     - Generated configs, scripts, logs
#   /home/pzserver/Zomboid    - PZ runtime directory (links to data)
# =============================================================================

SERVER_DIR="/home/pzserver/server"
DATA_DIR="/home/pzserver/data"
CACHE_DIR="/home/pzserver/.cache"
ZOMBOID_DIR="/home/pzserver/Zomboid"
STEAMCMD="/usr/bin/steamcmd"

# Sanitize server name - replace spaces with underscores for internal use
SERVER_NAME_SAFE=$(echo "${SERVER_NAME}" | tr ' ' '_' | tr -cd '[:alnum:]_-')
if [ -z "${SERVER_NAME_SAFE}" ]; then
    SERVER_NAME_SAFE="servertest"
fi

echo "=========================================="
echo "  ArcadeNode - Project Zomboid Server"
echo "=========================================="
echo "[INFO] Server Name: ${SERVER_NAME}"
echo "[INFO] Internal Name: ${SERVER_NAME_SAFE}"

# =============================================================================
# Setup .cache directory structure for generated files
# =============================================================================
echo "[INFO] Setting up cache directories..."
mkdir -p "${CACHE_DIR}/configs"      # Generated config files
mkdir -p "${CACHE_DIR}/scripts"      # Generated scripts (steamcmd, etc)
mkdir -p "${CACHE_DIR}/logs"         # Startup and operation logs
mkdir -p "${CACHE_DIR}/templates"    # Processed templates

# Log startup
echo "$(date -Iseconds) - Container starting: ${SERVER_NAME_SAFE}" >> "${CACHE_DIR}/logs/startup.log"

# =============================================================================
# Install/Update Project Zomboid via SteamCMD
# =============================================================================
echo "[INFO] Checking for server updates..."

# Build beta branch arguments if specified
BETA_ARGS=""
if [ -n "${BETA_BRANCH}" ]; then
    echo "[INFO] Using beta branch: ${BETA_BRANCH}"
    BETA_ARGS="-beta ${BETA_BRANCH}"
    if [ -n "${BETA_PASSWORD}" ]; then
        BETA_ARGS="${BETA_ARGS} -betapassword ${BETA_PASSWORD}"
    fi
fi

# Ensure server directory exists
mkdir -p "${SERVER_DIR}"

# Generate SteamCMD script in cache directory
cat > "${CACHE_DIR}/scripts/steamcmd_update.txt" << EOF
force_install_dir ${SERVER_DIR}
login anonymous
app_update ${STEAM_APP_ID} ${BETA_ARGS} validate
quit
EOF

echo "[INFO] Running SteamCMD..."
${STEAMCMD} +runscript "${CACHE_DIR}/scripts/steamcmd_update.txt" 2>&1 | tee -a "${CACHE_DIR}/logs/steamcmd.log" || echo "[WARN] SteamCMD completed with warnings"

# Verify installation succeeded
if [ ! -f "${SERVER_DIR}/start-server.sh" ]; then
    echo "[ERROR] Server installation failed - start-server.sh not found"
    
    # If beta was specified, try without beta (fallback to stable)
    if [ -n "${BETA_BRANCH}" ]; then
        echo "[INFO] Beta branch '${BETA_BRANCH}' may not be available. Trying stable version..."
        cat > "${CACHE_DIR}/scripts/steamcmd_update.txt" << EOF
force_install_dir ${SERVER_DIR}
login anonymous
app_update ${STEAM_APP_ID} validate
quit
EOF
        ${STEAMCMD} +runscript "${CACHE_DIR}/scripts/steamcmd_update.txt" 2>&1 | tee -a "${CACHE_DIR}/logs/steamcmd.log"
    else
        echo "[INFO] Retrying installation..."
        ${STEAMCMD} +runscript "${CACHE_DIR}/scripts/steamcmd_update.txt" 2>&1 | tee -a "${CACHE_DIR}/logs/steamcmd.log"
    fi
fi

# Final verification
if [ ! -f "${SERVER_DIR}/start-server.sh" ]; then
    echo "[FATAL] Server installation failed after retries. Please check SteamCMD logs."
    exit 1
fi

# =============================================================================
# Setup Zomboid runtime directories with symlinks to persistent storage
# =============================================================================
echo "[INFO] Setting up data directories..."

# Create persistent data structure
mkdir -p "${DATA_DIR}/Saves/Multiplayer"
mkdir -p "${DATA_DIR}/Server"
mkdir -p "${DATA_DIR}/Logs"
mkdir -p "${DATA_DIR}/db"

# Setup Zomboid directory structure
mkdir -p "${ZOMBOID_DIR}"

# Link data directories to expected locations (PZ expects these in ~/Zomboid/)
rm -rf "${ZOMBOID_DIR}/Saves" 2>/dev/null || true
rm -rf "${ZOMBOID_DIR}/Server" 2>/dev/null || true  
rm -rf "${ZOMBOID_DIR}/Logs" 2>/dev/null || true
rm -rf "${ZOMBOID_DIR}/db" 2>/dev/null || true

ln -sfn "${DATA_DIR}/Saves" "${ZOMBOID_DIR}/Saves"
ln -sfn "${DATA_DIR}/Server" "${ZOMBOID_DIR}/Server"
ln -sfn "${DATA_DIR}/Logs" "${ZOMBOID_DIR}/Logs"
ln -sfn "${DATA_DIR}/db" "${ZOMBOID_DIR}/db"

# =============================================================================
# Generate server configuration (store in cache, copy to data)
# =============================================================================
CONFIG_FILE="${DATA_DIR}/Server/${SERVER_NAME_SAFE}.ini"
CACHE_CONFIG="${CACHE_DIR}/configs/${SERVER_NAME_SAFE}.ini"

echo "[INFO] Generating server configuration..."

# Set default values for all environment variables to prevent envsubst issues
export PUBLIC_SERVER="${PUBLIC_SERVER:-true}"
export SERVER_NAME="${SERVER_NAME:-ArcadeNode_PZ_Server}"
export MAX_PLAYERS="${MAX_PLAYERS:-16}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export PAUSE_EMPTY="${PAUSE_EMPTY:-true}"
export SERVER_PORT="${SERVER_PORT:-16261}"
export DIRECT_PORT="${DIRECT_PORT:-16262}"
export RCON_PORT="${RCON_PORT:-27015}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-changeme}"
export STEAM_VAC="${STEAM_VAC:-true}"
export MOD_IDS="${MOD_IDS:-}"
export WORKSHOP_IDS="${WORKSHOP_IDS:-}"
export MAX_RAM="${MAX_RAM:-4096}"

# Always regenerate config template in cache
if [ -f "/home/pzserver/server.ini.template" ]; then
    envsubst < /home/pzserver/server.ini.template > "${CACHE_CONFIG}"
else
    cat > "${CACHE_CONFIG}" << EOF
# Project Zomboid Server Configuration
# Generated by ArcadeNode at $(date -Iseconds)

Public=${PUBLIC_SERVER}
PublicName=${SERVER_NAME}
PublicDescription=Managed by ArcadeNode Panel
MaxPlayers=${MAX_PLAYERS}
Password=${SERVER_PASSWORD}
PauseEmpty=${PAUSE_EMPTY}
DefaultPort=${SERVER_PORT}
UDPPort=${DIRECT_PORT}
RCONPort=${RCON_PORT}
RCONPassword=${ADMIN_PASSWORD}
SteamVAC=${STEAM_VAC}
Mods=${MOD_IDS}
WorkshopItems=${WORKSHOP_IDS}
Map=Muldraugh, KY
ResetID=0
Open=true
ServerWelcomeMessage=Welcome to ${SERVER_NAME}! <LINE> Managed by ArcadeNode.
GlobalChat=true
AutoCreateUserInWhiteList=false
DisplayUserName=true
ShowFirstAndLastName=false
SpawnPoint=0,0,0
SafetySystem=true
ShowSafety=true
SafetyToggleTimer=2
SafetyCooldownTimer=3
DoLuaChecksum=true
DenyLoginOnOverloadedServer=true
PVP=true
SafeHouse=true
BackupsCount=5
BackupsOnStart=true
BackupsOnVersionChange=true
BackupsPeriod=0
SteamScoreboard=true
SteamPort1=8766
SteamPort2=8767
VoiceEnable=true
EOF
fi

# Copy config to data if doesn't exist or REGENERATE_CONFIG is set
if [ ! -f "${CONFIG_FILE}" ] || [ "${REGENERATE_CONFIG}" = "true" ]; then
    cp "${CACHE_CONFIG}" "${CONFIG_FILE}"
    echo "[INFO] Configuration written to ${CONFIG_FILE}"
else
    echo "[INFO] Using existing config: ${CONFIG_FILE}"
fi

# =============================================================================
# Generate required Lua configuration files
# =============================================================================
echo "[INFO] Generating Lua configuration files..."

# Spawn points file
SPAWN_FILE="${DATA_DIR}/Server/${SERVER_NAME_SAFE}_spawnpoints.lua"
if [ ! -f "${SPAWN_FILE}" ]; then
    cat > "${CACHE_DIR}/templates/spawnpoints.lua" << 'EOFSPAWN'
function SpawnPoints()
end
EOFSPAWN
    cp "${CACHE_DIR}/templates/spawnpoints.lua" "${SPAWN_FILE}"
    echo "[INFO] Created spawn points file"
fi

# Spawn regions file
REGION_FILE="${DATA_DIR}/Server/${SERVER_NAME_SAFE}_spawnregions.lua"
if [ ! -f "${REGION_FILE}" ]; then
    cat > "${CACHE_DIR}/templates/spawnregions.lua" << 'EOFREG'
function SpawnRegions()
    return {}
end
EOFREG
    cp "${CACHE_DIR}/templates/spawnregions.lua" "${REGION_FILE}"
    echo "[INFO] Created spawn regions file"
fi

# Server database placeholder
SERVER_DB="${DATA_DIR}/db/${SERVER_NAME_SAFE}.db"
if [ ! -f "${SERVER_DB}" ]; then
    touch "${SERVER_DB}"
    echo "[INFO] Created server database placeholder"
fi

# =============================================================================
# Generate sandbox variables file
# =============================================================================
SANDBOX_FILE="${DATA_DIR}/Server/${SERVER_NAME_SAFE}_SandboxVars.lua"
if [ ! -f "${SANDBOX_FILE}" ]; then
    echo "[INFO] Creating sandbox variables file..."
    cat > "${CACHE_DIR}/templates/SandboxVars.lua" << 'EOFBOX'
SandboxVars = {
    Version = 5,
    Zombies = 4,
    Distribution = 1,
    DayLength = 2,
    StartYear = 1,
    StartMonth = 7,
    StartDay = 1,
    StartTime = 2,
    WaterShut = 14,
    ElecShut = 14,
    WaterShutModifier = 14,
    ElecShutModifier = 14,
    FoodLoot = 2,
    CannedFoodLoot = 2,
    LiteratureLoot = 2,
    SurvivalGearsLoot = 2,
    MedicalLoot = 2,
    WeaponLoot = 2,
    RangedWeaponLoot = 2,
    AmmoLoot = 2,
    MechanicsLoot = 2,
    OtherLoot = 2,
    Temperature = 3,
    Rain = 3,
    ErosionSpeed = 3,
    XpMultiplier = 1.0,
    Farming = 3,
    CompostTime = 2,
    StatsDecrease = 3,
    NatureAbundance = 3,
    Alarm = 6,
    LockedHouses = 6,
    FoodRotSpeed = 3,
    FridgeFactor = 3,
    LootRespawn = 1,
    TimeSinceApo = 1,
    PlantResilience = 3,
    PlantAbundance = 3,
    EndRegen = 3,
    Helicopter = 3,
    MetaEvent = 2,
    SleepingEvent = 2,
    GeneratorSpawning = 3,
    GeneratorFuelConsumption = 3,
    SurvivorHouseChance = 3,
    VehicleEasyUse = false,
    Zombies = 4,
    ZombieSpeed = 3,
    ZombieStrength = 3,
    ZombieToughness = 3,
    ZombieTransmission = 1,
    ZombieInfectionMortality = 5,
    ZombieCognition = 3,
    ZombieMemory = 3,
    ZombieDecomposition = 3,
    ZombieSight = 3,
    ZombieHearing = 3,
    ZombieSmell = 3,
}
EOFBOX
    cp "${CACHE_DIR}/templates/SandboxVars.lua" "${SANDBOX_FILE}"
fi

# =============================================================================
# Create world save directory
# =============================================================================
WORLD_DIR="${DATA_DIR}/Saves/Multiplayer/${SERVER_NAME_SAFE}"
if [ ! -d "${WORLD_DIR}" ]; then
    echo "[INFO] Creating world save directory..."
    mkdir -p "${WORLD_DIR}"
fi

# =============================================================================
# Display startup summary
# =============================================================================
echo ""
echo "=========================================="
echo "  Server Configuration Summary"
echo "=========================================="
echo "[INFO] Server Name: ${SERVER_NAME_SAFE}"
echo "[INFO] Max Players: ${MAX_PLAYERS}"
echo "[INFO] Max RAM: ${MAX_RAM}MB"
echo "[INFO] Game Port: ${SERVER_PORT}/udp"
echo "[INFO] Direct Port: ${DIRECT_PORT}/udp"
echo "[INFO] RCON Port: ${RCON_PORT}/tcp"
echo "[INFO] Config: ${CONFIG_FILE}"
echo "[INFO] Cache: ${CACHE_DIR}"
echo "[INFO] Data: ${DATA_DIR}"
echo "=========================================="
echo ""

# Log to cache
echo "$(date -Iseconds) - Server starting with config: ${CONFIG_FILE}" >> "${CACHE_DIR}/logs/startup.log"

# Debug: Show directory structure
echo "[DEBUG] Cache directory contents:"
ls -la "${CACHE_DIR}/" 2>/dev/null || echo "  (empty)"
echo "[DEBUG] Server config directory:"
ls -la "${DATA_DIR}/Server/" 2>/dev/null || echo "  (empty)"
echo "[DEBUG] Zomboid directory structure:"
ls -la "${ZOMBOID_DIR}/" 2>/dev/null || echo "  (empty)"
echo "[DEBUG] Symlink status:"
ls -la "${ZOMBOID_DIR}/Server" 2>/dev/null || echo "  Server symlink missing!"
ls -la "${ZOMBOID_DIR}/Saves" 2>/dev/null || echo "  Saves symlink missing!"

# Verify symlinks are pointing to correct locations
echo "[DEBUG] Checking if symlinks are valid:"
if [ -L "${ZOMBOID_DIR}/Server" ] && [ -d "$(readlink -f ${ZOMBOID_DIR}/Server)" ]; then
    echo "  Server symlink: OK -> $(readlink -f ${ZOMBOID_DIR}/Server)"
else
    echo "  Server symlink: BROKEN - recreating..."
    rm -f "${ZOMBOID_DIR}/Server"
    mkdir -p "${DATA_DIR}/Server"
    ln -sfn "${DATA_DIR}/Server" "${ZOMBOID_DIR}/Server"
fi

if [ -L "${ZOMBOID_DIR}/Saves" ] && [ -d "$(readlink -f ${ZOMBOID_DIR}/Saves)" ]; then
    echo "  Saves symlink: OK -> $(readlink -f ${ZOMBOID_DIR}/Saves)"
else
    echo "  Saves symlink: BROKEN - recreating..."
    rm -f "${ZOMBOID_DIR}/Saves"
    mkdir -p "${DATA_DIR}/Saves/Multiplayer"
    ln -sfn "${DATA_DIR}/Saves" "${ZOMBOID_DIR}/Saves"
fi

# Set server memory
export JAVA_OPTS="-Xms${MAX_RAM}m -Xmx${MAX_RAM}m"

# =============================================================================
# Start Project Zomboid Server
# =============================================================================
cd ${SERVER_DIR}

# Set HOME and cache directories
export HOME="/home/pzserver"
export PZ_CACHE_DIR="${CACHE_DIR}"

# =============================================================================
# Signal Handling for graceful shutdown
# =============================================================================
cleanup() {
    echo "[INFO] Received shutdown signal, stopping server gracefully..."
    # Send quit command to the server if possible
    if [ -n "$SERVER_PID" ]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

echo "[INFO] Starting Project Zomboid Server..."
echo "[DEBUG] Working directory: $(pwd)"
echo "[DEBUG] Start script exists: $(ls -la start-server.sh 2>&1)"

# Make absolutely sure all directories exist with proper permissions
chmod -R 777 "${ZOMBOID_DIR}" 2>/dev/null || true
chmod -R 777 "${DATA_DIR}" 2>/dev/null || true

# Use the official start-server.sh script which handles Java setup correctly
if [ -f "start-server.sh" ]; then
    echo "[INFO] Using official start-server.sh wrapper..."
    
    # Set environment for proper server operation
    export HOME="/home/pzserver"
    export USER="pzserver"
    
    # The server needs these options passed correctly
    # Build 42+ uses different command line parsing
    
    # Create a server options file that PZ will read
    mkdir -p "${ZOMBOID_DIR}/Server"
    
    # Run the server with proper arguments
    # Note: Build 42+ requires arguments in specific format
    exec ./start-server.sh \
        -servername "${SERVER_NAME_SAFE}" \
        -adminpassword "${ADMIN_PASSWORD}" \
        -ip 0.0.0.0 \
        -port ${SERVER_PORT} \
        -steamport1 ${DIRECT_PORT} \
        -cachedir="${ZOMBOID_DIR}"
else
    echo "[ERROR] start-server.sh not found!"
    echo "[DEBUG] Contents of server directory:"
    ls -la
    exit 1
fi
