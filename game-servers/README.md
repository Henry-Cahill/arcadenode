# ArcadeNode Game Server Cartridges

This directory contains Docker configurations for game server "cartridges" - pre-built templates that ArcadeNode uses to spawn game server containers.

## 📦 Available Cartridges

| Game | Directory | Steam App ID | Base Image |
|------|-----------|--------------|------------|
| 🧟 Project Zomboid | `project-zomboid/` | 380870 | steamcmd/steamcmd:ubuntu-24 |
| 🎖️ Arma Reforger | `arma-reforger/` | 1874900 | steamcmd/steamcmd:ubuntu-24 |
| ⛏️ Minecraft Java | `minecraft/` | N/A | eclipse-temurin:21-jre-alpine |
| 🪨 Minecraft Bedrock | `minecraft-bedrock/` | N/A | ubuntu:24.04 |

## 🏗️ Building Images

### Automated Build (Recommended)

Use the included build scripts for easy image management:

#### Linux/macOS (Shell Script)

```bash
# Build all images
./build.sh

# Build specific images
./build.sh minecraft minecraft-bedrock

# Build with version tag
./build.sh -v 1.0.0

# Build and push to registry
./build.sh -r ghcr.io/username -p

# Build in parallel (faster)
./build.sh -P

# List available images
./build.sh -l

# Clean all ArcadeNode images
./build.sh -c

# Show help
./build.sh -h
```

#### Windows (PowerShell)

```powershell
# Build all images
.\build.ps1

# Build specific images
.\build.ps1 minecraft minecraft-bedrock

# Build with version tag
.\build.ps1 -Version 1.0.0

# Build and push to registry
.\build.ps1 -Registry ghcr.io/username -Push

# Build on remote host
.\build.ps1 -RemoteHost user@192.168.1.100

# List available images
.\build.ps1 -List

# Clean all ArcadeNode images
.\build.ps1 -Clean
```

#### Make (Unix/WSL)

```bash
# Build all images
make

# Build specific image
make minecraft

# Build with version
make VERSION=1.0.0

# Build and push
make push REGISTRY=ghcr.io/username

# Clean images
make clean

# Show help
make help
```

### Manual Build

```bash
# Using docker-compose
docker-compose build

# Or build individually
docker build -t arcadenode/project-zomboid:latest ./project-zomboid
docker build -t arcadenode/arma-reforger:latest ./arma-reforger
docker build -t arcadenode/minecraft:latest ./minecraft
docker build -t arcadenode/minecraft-bedrock:latest ./minecraft-bedrock
```

### Push to Registry (Optional)

```bash
# Tag for your registry
docker tag arcadenode/project-zomboid:latest your-registry.com/arcadenode/project-zomboid:latest

# Push
docker push your-registry.com/arcadenode/project-zomboid:latest
```

## 🎮 Game Cartridge Details

### Project Zomboid

**Ports:**
- `16261/udp` - Game port
- `16262/udp` - Direct connection port
- `27015/tcp` - RCON port

**Key Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | ArcadeNode PZ Server | Server display name |
| `SERVER_PASSWORD` | (empty) | Server password |
| `ADMIN_PASSWORD` | changeme | Admin/RCON password |
| `MAX_PLAYERS` | 16 | Maximum players |
| `MAX_RAM` | 4096 | RAM allocation (MB) |
| `MOD_IDS` | (empty) | Comma-separated mod IDs |
| `WORKSHOP_IDS` | (empty) | Steam Workshop IDs |

---

### Arma Reforger

**Ports:**
- `2001/udp` - Game port
- `17777/udp` - Steam Query/A2S port

**Key Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | ArcadeNode Reforger Server | Server display name |
| `SERVER_PASSWORD` | (empty) | Server password |
| `ADMIN_PASSWORD` | changeme | Admin password |
| `MAX_PLAYERS` | 64 | Maximum players |
| `SCENARIO_ID` | Conflict (Everon) | Mission scenario |
| `CROSSPLATFORM` | true | Allow Xbox players |
| `BATTLYE` | true | BattlEye enabled |
| `MODS` | (empty) | Comma-separated mod IDs |

**Scenario Options:**
- `{ECC61978EDCC2B5A}Missions/23_Campaign.conf` - Conflict (Everon)
- `{59AD59368755F41A}Missions/21_GM_Eden.conf` - Game Master (Everon)
- `{28802845ADA64D52}Missions/22_GM_Arland.conf` - Game Master (Arland)

---

### Minecraft Java

**Ports:**
- `25565/tcp` & `25565/udp` - Game port
- `25575/tcp` - RCON port

**Key Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_TYPE` | paper | Server type (paper/vanilla/spigot) |
| `MC_VERSION` | 1.21.1 | Minecraft version |
| `SERVER_NAME` | ArcadeNode MC Server | Server name |
| `MOTD` | ArcadeNode Minecraft Server | Message of the day |
| `MAX_PLAYERS` | 20 | Maximum players |
| `GAMEMODE` | survival | Default gamemode |
| `DIFFICULTY` | normal | Difficulty level |
| `MAX_RAM` | 2G | Maximum RAM |
| `MIN_RAM` | 1G | Minimum RAM |
| `ONLINE_MODE` | true | Verify Mojang accounts |
| `OPS` | (empty) | Comma-separated op usernames |

---

### Minecraft Bedrock

**Ports:**
- `19132/udp` - Game port (IPv4)
- `19133/udp` - Game port (IPv6)

**Key Environment Variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `VERSION` | LATEST | Server version (LATEST or specific) |
| `SERVER_NAME` | ArcadeNode Bedrock Server | Server name |
| `MAX_PLAYERS` | 10 | Maximum players |
| `GAMEMODE` | survival | Default gamemode |
| `DIFFICULTY` | normal | Difficulty level |
| `LEVEL_NAME` | Bedrock level | World name |
| `LEVEL_SEED` | (empty) | World seed |
| `VIEW_DISTANCE` | 32 | View distance (chunks) |
| `ONLINE_MODE` | true | Xbox Live authentication |
| `WHITE_LIST` | false | Enable allowlist |
| `ALLOW_LIST_USERS` | (empty) | Comma-separated Xbox Gamertags |
| `OPS` | (empty) | Comma-separated operator XUIDs |
| `SERVER_AUTHORITATIVE_MOVEMENT` | server-auth | Anti-cheat mode |

## 📁 Volume Mounts

Each cartridge uses persistent volumes for game data:

| Game | Volume | Purpose |
|------|--------|---------|
| Project Zomboid | `/home/pzserver/data` | Saves, configs, logs |
| Arma Reforger | `/home/reforger/data` | Profile, addons, configs |
| Minecraft Java | `/home/minecraft/data` | Worlds, logs |
| Minecraft Java | `/home/minecraft/plugins` | Server plugins |
| Minecraft Bedrock | `/home/bedrock/data` | Worlds, resource/behavior packs |

## 🔧 Integration with ArcadeNode

These cartridges are designed to work with the ArcadeNode panel:

1. **Dynamic Provisioning** - Panel creates containers with appropriate environment variables
2. **Port Allocation** - Panel manages port assignments from node allocations
3. **Resource Limits** - Memory and CPU limits applied per-server
4. **Console Access** - Logs streamed to panel via Docker API
5. **Power Management** - Start/stop/restart via panel interface

## 🛠️ Customization

To add a new game server cartridge:

1. Create a new directory under `game-servers/`
2. Add a `Dockerfile` with the server setup
3. Create an `entrypoint.sh` for startup logic
4. Add configuration templates as needed
5. Create a standalone `docker-compose.yml` for testing
6. Register the game in ArcadeNode's Eggs database
7. Add the image to `build.sh` and `Makefile`

## ⚠️ Notes

- **Steam Games**: Servers using SteamCMD will download game files on first start (can take several minutes)
- **Memory**: Ensure Docker has enough memory allocated for the servers
- **Ports**: Make sure firewall allows the required ports
- **Persistence**: Always mount volumes for game data to survive container restarts
- **Build Scripts**: Use `./build.sh` or `make` for consistent, automated builds
