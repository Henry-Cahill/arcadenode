# ArcadeNode

<div align="center">
  <img src="frontend/public/arcadenode.svg" alt="ArcadeNode Logo" width="120" height="120" />
  
  **Game Server Management Panel**
  
  *Host and manage your game servers with ease*
  
  [![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
  [![.NET](https://img.shields.io/badge/.NET-9.0-purple)](https://dotnet.microsoft.com/)
  [![React](https://img.shields.io/badge/React-18-61dafb)](https://react.dev/)
</div>

---

## 🎮 Supported Games

<table>
  <tr>
    <td align="center">
      <img src="https://img.shields.io/badge/Project%20Zomboid-4ade80?style=for-the-badge&logo=steam&logoColor=white" alt="Project Zomboid"/>
      <br/>Survival Horror
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Arma%20Reforger-f97316?style=for-the-badge&logo=steam&logoColor=white" alt="Arma Reforger"/>
      <br/>Military Simulation
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Minecraft%20Java-84cc16?style=for-the-badge&logo=minecraft&logoColor=white" alt="Minecraft Java"/>
      <br/>Sandbox Adventure
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Minecraft%20Bedrock-a855f7?style=for-the-badge&logo=minecraft&logoColor=white" alt="Minecraft Bedrock"/>
      <br/>Cross-Platform
    </td>
  </tr>
</table>

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎮 **Game Server Management** | Create, start, stop, and restart game servers with one click |
| 📊 **Real-time Monitoring** | Live CPU, memory, disk, and network usage statistics |
| 🖥️ **Console Access** | View logs and send commands directly to your servers |
| 👥 **User Management** | Role-based access control (User, SubUser, Admin, SuperAdmin) |
| 🔧 **Node Management** | Manage multiple Docker nodes across your infrastructure |
| 🥚 **Game Templates** | Pre-configured templates for Project Zomboid, Arma Reforger, Minecraft Java & Bedrock |
| 🔐 **Secure Authentication** | JWT-based authentication with BCrypt password hashing |
| 🌐 **Modern UI** | Beautiful dark theme with responsive design |

## 🛠️ Tech Stack

- **Backend**: .NET 9 with ASP.NET Core Web API
- **Database**: SQL Server 2025
- **Frontend**: React 18 + TypeScript + Vite + TailwindCSS
- **Containerization**: Docker & Docker Compose

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Docker Compose v2.0+

### Running with Docker Compose

```bash
# Clone and navigate to the project
cd ArcadeNode

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f
```

### Access Points

| Service | URL |
|---------|-----|
| 🌐 **Panel** | http://localhost:3000 |
| 🔌 **API** | http://localhost:5000 |
| 📖 **API Docs** | http://localhost:5000/swagger |

### Default Credentials

The first startup seeds a single `admin` account:

- Its password comes from `ADMIN_PASSWORD` in your `.env` (see `.env.example`).
- If `ADMIN_PASSWORD` is unset, a random password is generated and printed **once**
  in the backend logs - capture it from `docker-compose logs backend`.

> ⚠️ **Important**: Change the password immediately after first login.

## 💻 Development Setup

### Backend (.NET 9)

```bash
cd backend/ServerPanel.API

# Restore packages
dotnet restore

# Run with hot reload
dotnet watch run
```

### Frontend (React)

```bash
cd frontend

# Install dependencies
npm install

# Run development server
npm run dev
```

## 📁 Project Structure

```
ArcadeNode/
├── 📄 docker-compose.yml      # Docker orchestration
├── � .env.example             # Environment template
├── 📂 scripts/                 # Deployment & management scripts
│   ├── 📄 deploy.ps1           # Full deployment (PowerShell)
│   ├── 📄 deploy.sh            # Full deployment (Bash)
│   ├── 📄 quick-deploy.ps1     # Quick iteration deploy
│   ├── 📄 deploy-wizard.sh     # Interactive game server wizard
│   └── 📄 init-setup.sh        # First-time setup
├── 📂 backend/
│   ├── 🐳 Dockerfile
│   └── 📂 ServerPanel.API/
│       ├── 📂 Controllers/    # API endpoints
│       ├── 📂 Data/           # EF Core DbContext
│       ├── 📂 DTOs/           # Data transfer objects
│       ├── 📂 Models/         # Entity models
│       ├── 📂 Services/       # Business logic
│       └── 📄 Program.cs      # Application entry
├── 📂 frontend/
│   ├── 🐳 Dockerfile
│   ├── 📄 nginx.conf
│   └── 📂 src/
│       ├── 📂 components/     # React components
│       ├── 📂 pages/          # Page components
│       ├── 📂 services/       # API services
│       ├── 📂 stores/         # Zustand state stores
│       └── 📂 types/          # TypeScript types
├── 📂 cartridges/              # Game server cartridge definitions
│   ├── 📂 minecraft-java/
│   └── 📂 project-zomboid/
├── 📂 game-servers/            # Game server Docker configs
│   ├── 📂 project-zomboid/    # PZ dedicated server
│   ├── 📂 arma-reforger/      # Reforger dedicated server
│   ├── 📂 minecraft/          # MC Java (Paper/Vanilla)
│   ├── 📂 minecraft-bedrock/  # MC Bedrock server
│   └── 📂 wizards/            # Game deployment wizard modules
└── 📂 docs/                    # Documentation
```

## 🔌 API Reference

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/login` | User login |
| `POST` | `/api/auth/register` | User registration |
| `GET` | `/api/auth/me` | Get current user |
| `PUT` | `/api/auth/me` | Update profile |
| `POST` | `/api/auth/change-password` | Change password |

### Servers

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/servers` | List all servers |
| `GET` | `/api/servers/{id}` | Get server details |
| `POST` | `/api/servers` | Create server (Admin) |
| `PUT` | `/api/servers/{id}` | Update server |
| `DELETE` | `/api/servers/{id}` | Delete server (Admin) |
| `POST` | `/api/servers/{id}/power` | Power action |
| `GET` | `/api/servers/{id}/logs` | Get console logs |
| `POST` | `/api/servers/{id}/command` | Send command |
| `GET` | `/api/servers/{id}/stats` | Get resource stats |

### Nodes (Admin)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/nodes` | List nodes |
| `POST` | `/api/nodes` | Create node |
| `PUT` | `/api/nodes/{id}` | Update node |
| `DELETE` | `/api/nodes/{id}` | Delete node |
| `GET` | `/api/nodes/{id}/allocations` | Get allocations |
| `POST` | `/api/nodes/{id}/allocations` | Create allocations |

### Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/admin/dashboard` | Dashboard stats |
| `GET` | `/api/admin/users` | List users |
| `DELETE` | `/api/admin/users/{id}` | Delete user |
| `GET` | `/api/admin/nests` | List game categories |
| `GET` | `/api/admin/eggs` | List game templates |

## ⚙️ Environment Variables

### Backend

| Variable | Description | Default |
|----------|-------------|---------|
| `ConnectionStrings__DefaultConnection` | SQL Server connection | - |
| `Jwt__Key` | JWT signing key | Auto-generated |
| `Jwt__Issuer` | JWT issuer | ArcadeNode |
| `Jwt__Audience` | JWT audience | ArcadeNodeUsers |
| `Docker__NodeUrl` | Docker daemon URL | tcp://node:2375 |

### Frontend

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API URL | /api |

## 🎮 Game Server Templates

### Project Zomboid
- Dedicated server with mod support
- Customizable world settings
- Steam Workshop integration

### Arma Reforger
- Official dedicated server
- Mod support via Workshop
- Mission file management

### Minecraft Java Edition
- Paper/Spigot/Vanilla support
- Plugin management
- World backup system
- Optimized with Aikar's flags

### Minecraft Bedrock Edition
- Official Bedrock Dedicated Server
- Cross-platform (Xbox, Mobile, Windows 10/11)
- Server-authoritative anti-cheat
- Resource & behavior pack support

## 🗄️ Database

The panel uses SQL Server 2025 with Entity Framework Core. The database is automatically migrated on startup.

### Models
- **User** - Panel users with roles
- **GameServer** - Game server instances
- **Node** - Docker nodes for hosting servers
- **Allocation** - IP:Port allocations
- **Nest** - Game categories (Survival, Military, Sandbox)
- **Egg** - Game server templates with startup configs
- **Backup** - Server backups
- **Schedule** - Scheduled tasks

## 🔒 Security

- **JWT Authentication** - Secure token-based auth
- **BCrypt Hashing** - Industry-standard password hashing
- **Role-Based Access** - Granular permission system
- **CORS Policy** - Controlled cross-origin access

## 📄 License

MIT License

---

<div align="center">
  <strong>ArcadeNode</strong> — Built with 💜 for gamers
</div>
