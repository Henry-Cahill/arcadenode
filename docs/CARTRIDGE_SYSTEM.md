# ArcadeNode Cartridge System

## Overview

Cartridges are self-contained game server definitions inspired by Pterodactyl's Egg system. Each cartridge defines everything needed to deploy and manage a specific game server type.

## Pterodactyl Egg Structure Analysis

### Core Components of a Pterodactyl Egg

```json
{
    "meta": {
        "version": "PTDL_v2"
    },
    "name": "Project Zomboid",
    "author": "email@example.com",
    "description": "Game description",
    "features": ["steam_disk_space"],
    
    // Docker images to use
    "docker_images": {
        "ghcr.io/parkervcp/steamcmd:debian": "ghcr.io/parkervcp/steamcmd:debian"
    },
    
    // Startup command with variables
    "startup": "./ProjectZomboid64 -port {{SERVER_PORT}} -servername \"{{SERVER_NAME}}\"",
    
    // Process management configuration
    "config": {
        "files": "{}",                          // Config file parsers
        "startup": "{\"done\": \"SERVER STARTED\"}",  // Ready detection
        "logs": "{}",
        "stop": "quit"                          // Stop command
    },
    
    // Installation script
    "scripts": {
        "installation": {
            "script": "#!/bin/bash\n...",
            "container": "ghcr.io/parkervcp/installers:debian",
            "entrypoint": "bash"
        }
    },
    
    // User-configurable variables
    "variables": [
        {
            "name": "Server Name",
            "description": "The server name",
            "env_variable": "SERVER_NAME",
            "default_value": "MyServer",
            "user_viewable": true,
            "user_editable": true,
            "rules": "required|string|max:64",
            "field_type": "text"
        }
    ]
}
```

### Key Pterodactyl Features

1. **Variable Substitution**: `{{VARIABLE}}` in startup commands
2. **Config File Parsing**: Automatic modification of game configs (properties, yaml, json, ini)
3. **Ready Detection**: Pattern matching on stdout to know when server is ready
4. **Installation Scripts**: Separate container for installation
5. **Default Variables**: `SERVER_MEMORY`, `SERVER_PORT`, `SERVER_IP`, `TZ`, etc.

---

## ArcadeNode Cartridge Design

### Cartridge JSON Schema

```json
{
    "$schema": "https://arcadenode.io/schemas/cartridge-v1.json",
    "meta": {
        "version": "1.0",
        "format": "ARCADENODE_V1"
    },
    
    "id": "project-zomboid",
    "name": "Project Zomboid",
    "author": "ArcadeNode Team",
    "description": "Project Zomboid dedicated server",
    "category": "survival",
    "tags": ["zombie", "survival", "multiplayer", "steamcmd"],
    "website": "https://projectzomboid.com",
    
    // Docker configuration
    "docker": {
        "image": "arcadenode/project-zomboid:latest",
        "build": {
            "dockerfile": "Dockerfile",
            "context": "."
        }
    },
    
    // Port definitions
    "ports": {
        "game": {
            "default": 16261,
            "protocol": "udp",
            "required": true,
            "description": "Main game port"
        },
        "steam": {
            "default": 16262,
            "protocol": "udp",
            "required": true,
            "description": "Steam query port"
        },
        "rcon": {
            "default": 27015,
            "protocol": "tcp",
            "required": false,
            "description": "RCON administration port"
        }
    },
    
    // Resource defaults
    "resources": {
        "memory": {
            "minimum": 2048,
            "recommended": 4096,
            "maximum": 16384
        },
        "cpu": {
            "minimum": 1,
            "recommended": 2
        },
        "disk": {
            "minimum": 10240,
            "recommended": 20480
        }
    },
    
    // Startup configuration
    "startup": {
        "command": "./start-server.sh -servername \"{{SERVER_NAME}}\" -adminpassword \"{{ADMIN_PASSWORD}}\" -port {{GAME_PORT}}",
        "ready_pattern": "SERVER STARTED",
        "timeout": 300
    },
    
    // Process management
    "process": {
        "stop_command": "quit",
        "stop_timeout": 30,
        "restart_on_crash": true,
        "crash_detection": {
            "patterns": ["FATAL ERROR", "OutOfMemoryError"],
            "action": "restart"
        }
    },
    
    // Installation steps
    "installation": {
        "type": "steamcmd",
        "app_id": 380870,
        "anonymous": true,
        "validate": true,
        "beta": {
            "branch_variable": "BETA_BRANCH",
            "password_variable": "BETA_PASSWORD"
        },
        "post_install": [
            "chmod +x start-server.sh"
        ]
    },
    
    // Config file management
    "config_files": {
        "server.ini": {
            "parser": "ini",
            "location": "{{DATA_DIR}}/Server/{{SERVER_NAME_SAFE}}.ini",
            "template": "server.ini.template",
            "mappings": {
                "PublicName": "{{SERVER_NAME}}",
                "MaxPlayers": "{{MAX_PLAYERS}}",
                "DefaultPort": "{{GAME_PORT}}",
                "Password": "{{SERVER_PASSWORD}}",
                "RCONPassword": "{{ADMIN_PASSWORD}}"
            }
        }
    },
    
    // Variables exposed to users
    "variables": [
        {
            "id": "server_name",
            "name": "Server Name",
            "description": "Display name of your server",
            "env_variable": "SERVER_NAME",
            "type": "string",
            "default": "My PZ Server",
            "required": true,
            "user_viewable": true,
            "user_editable": true,
            "validation": {
                "min_length": 1,
                "max_length": 64,
                "pattern": "^[a-zA-Z0-9 _-]+$"
            },
            "ui": {
                "component": "text",
                "placeholder": "Enter server name"
            }
        },
        {
            "id": "max_players",
            "name": "Max Players",
            "description": "Maximum concurrent players",
            "env_variable": "MAX_PLAYERS",
            "type": "integer",
            "default": 16,
            "required": true,
            "user_viewable": true,
            "user_editable": true,
            "validation": {
                "min": 1,
                "max": 100
            },
            "ui": {
                "component": "slider",
                "step": 1
            }
        },
        {
            "id": "admin_password",
            "name": "Admin Password",
            "description": "Password for admin account",
            "env_variable": "ADMIN_PASSWORD",
            "type": "string",
            "default": "",
            "required": true,
            "user_viewable": false,
            "user_editable": true,
            "validation": {
                "min_length": 8,
                "max_length": 64
            },
            "ui": {
                "component": "password"
            }
        },
        {
            "id": "mods",
            "name": "Workshop Mods",
            "description": "Steam Workshop mod IDs (comma-separated)",
            "env_variable": "WORKSHOP_IDS",
            "type": "string",
            "default": "",
            "required": false,
            "user_viewable": true,
            "user_editable": true,
            "ui": {
                "component": "textarea",
                "placeholder": "2392709985,2313387159"
            }
        }
    ],
    
    // System variables (not user-editable)
    "system_variables": {
        "STEAM_APP_ID": "380870",
        "SERVER_NAME_SAFE": "{{SERVER_NAME | sanitize}}",
        "DATA_DIR": "/home/pzserver/data",
        "CACHE_DIR": "/home/pzserver/.cache"
    },
    
    // Volume mounts
    "volumes": {
        "data": {
            "container_path": "/home/pzserver/data",
            "description": "Persistent game data",
            "required": true
        }
    },
    
    // Health check configuration
    "health_check": {
        "type": "udp",
        "port": "{{GAME_PORT}}",
        "interval": 30,
        "timeout": 10,
        "start_period": 120,
        "retries": 3
    },
    
    // Backup configuration
    "backup": {
        "paths": [
            "{{DATA_DIR}}/Saves",
            "{{DATA_DIR}}/Server"
        ],
        "exclude": [
            "*.log",
            "*.tmp"
        ]
    },
    
    // Console commands
    "console": {
        "enabled": true,
        "commands": {
            "players": {
                "command": "players",
                "description": "List online players"
            },
            "kick": {
                "command": "kickuser \"{{username}}\"",
                "description": "Kick a player",
                "parameters": ["username"]
            },
            "save": {
                "command": "save",
                "description": "Force save the world"
            }
        }
    },
    
    // Update configuration
    "updates": {
        "auto_update": true,
        "check_interval": 3600,
        "method": "steamcmd"
    }
}
```

---

## Directory Structure

```
cartridges/
├── project-zomboid/
│   ├── cartridge.json          # Main definition
│   ├── Dockerfile              # Docker build file
│   ├── entrypoint.sh           # Container entrypoint
│   ├── templates/
│   │   ├── server.ini.template
│   │   ├── SandboxVars.lua.template
│   │   └── spawnpoints.lua.template
│   ├── scripts/
│   │   ├── install.sh          # Installation script
│   │   ├── update.sh           # Update script
│   │   └── backup.sh           # Backup script
│   └── README.md
│
├── minecraft-java/
│   ├── cartridge.json
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── templates/
│   │   ├── server.properties.template
│   │   └── eula.txt
│   └── scripts/
│       └── install.sh
│
└── minecraft-bedrock/
    ├── cartridge.json
    ├── Dockerfile
    ├── entrypoint.sh
    └── templates/
        └── server.properties.template
```

---

## Variable Substitution

### Syntax

| Syntax | Description |
|--------|-------------|
| `{{VAR}}` | Simple substitution |
| `{{VAR\|default:value}}` | Default value if empty |
| `{{VAR\|sanitize}}` | Sanitize for filenames |
| `{{VAR\|upper}}` | Uppercase |
| `{{VAR\|lower}}` | Lowercase |
| `{{VAR\|base64}}` | Base64 encode |

### Built-in Variables

| Variable | Description |
|----------|-------------|
| `SERVER_MEMORY` | Allocated RAM in MB |
| `SERVER_PORT` | Primary port |
| `SERVER_IP` | Server IP address |
| `SERVER_UUID` | Unique server identifier |
| `NODE_ID` | Node identifier |
| `TZ` | Timezone |

---

## Config File Parsers

### Supported Parsers

1. **properties** - Java properties files
2. **ini** - INI configuration files
3. **json** - JSON files
4. **yaml** - YAML files
5. **xml** - XML files
6. **lua** - Lua configuration tables

### Parser Configuration Example

```json
{
    "config_files": {
        "server.properties": {
            "parser": "properties",
            "location": "/server/server.properties",
            "mappings": {
                "server-port": "{{GAME_PORT}}",
                "max-players": "{{MAX_PLAYERS}}",
                "motd": "{{SERVER_NAME}}"
            }
        },
        "config.yml": {
            "parser": "yaml",
            "location": "/server/plugins/plugin/config.yml",
            "mappings": {
                "settings.port": "{{GAME_PORT}}",
                "settings.players[0].name": "admin"
            }
        }
    }
}
```

---

## UI Components for Variables

| Component | Description | Options |
|-----------|-------------|---------|
| `text` | Single line text input | `placeholder`, `prefix`, `suffix` |
| `textarea` | Multi-line text | `rows`, `placeholder` |
| `password` | Password input | `show_toggle` |
| `number` | Numeric input | `min`, `max`, `step` |
| `slider` | Range slider | `min`, `max`, `step`, `marks` |
| `switch` | Boolean toggle | `on_label`, `off_label` |
| `select` | Dropdown select | `options: [{value, label}]` |
| `multiselect` | Multiple selection | `options: [{value, label}]` |
| `checkbox` | Checkbox | `label` |

---

## Implementation Plan

### Phase 1: Core System
1. Create `Cartridge` model in backend
2. Create `CartridgeService` to parse cartridge.json
3. Update `DeploymentController` to use cartridges
4. Migrate existing game servers to cartridge format

### Phase 2: Variable System
1. Implement variable substitution engine
2. Create config file parsers
3. Build validation system

### Phase 3: Frontend
1. Create CartridgeSelector component
2. Build dynamic variable form generator
3. Add cartridge management UI

### Phase 4: Advanced Features
1. Console command system
2. Backup automation
3. Update detection & automation
4. Health check monitoring

---

## Migration from Current System

### Current Structure
```
game-servers/
├── project-zomboid/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── server.ini.template
```

### New Cartridge Structure
```
cartridges/
├── project-zomboid/
│   ├── cartridge.json          # NEW: Main definition
│   ├── Dockerfile              # Keep
│   ├── entrypoint.sh           # Keep (simplified)
│   └── templates/
│       └── server.ini.template # Move here
```

### Migration Steps

1. Create `cartridge.json` for each game server
2. Move templates to `templates/` subdirectory
3. Update entrypoint scripts to read from environment
4. Update backend to load cartridge definitions
5. Update frontend to display cartridge options

---

## Comparison: Pterodactyl vs ArcadeNode

| Feature | Pterodactyl | ArcadeNode |
|---------|-------------|------------|
| Definition Format | JSON (Egg) | JSON (Cartridge) |
| Variable Syntax | `{{VAR}}` | `{{VAR}}` |
| Config Parsers | 6 types | 6 types |
| Installation | Separate container | Integrated in entrypoint |
| Docker Images | Pre-built yolks | Custom per cartridge |
| UI Components | Basic | Rich (slider, multiselect) |
| Ready Detection | Pattern match | Pattern match |
| Console Commands | Limited | Full definition |
| Backup Config | None | Integrated |

---

## Next Steps

1. [ ] Design `Cartridge` database model
2. [ ] Create `CartridgeService` in backend
3. [ ] Convert Project Zomboid to cartridge format
4. [ ] Convert Minecraft Java to cartridge format
5. [ ] Build cartridge parser/validator
6. [ ] Create frontend cartridge selector
7. [ ] Build dynamic form generator
