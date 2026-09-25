using ServerPanel.API.DTOs;

namespace ServerPanel.API.Services;

public interface IGameTemplateService
{
    IEnumerable<GameTemplateDto> GetAllTemplates();
    GameTemplateDto? GetTemplateById(string id);
    IEnumerable<GameTemplateDto> GetTemplatesByCategory(string category);
}

public class GameTemplateService : IGameTemplateService
{
    private static readonly List<GameTemplateDto> _templates = new()
    {
        // Minecraft Java Edition
        new GameTemplateDto(
            Id: "minecraft-java",
            Name: "Minecraft Java Edition",
            Description: "Paper/Vanilla/Spigot Minecraft server with plugin support and optimized JVM flags",
            Icon: "⛏️",
            Category: "Minecraft",
            DockerImage: "arcadenode/minecraft:latest",
            DefaultMemory: 2048,
            DefaultCpu: 100,
            DefaultDisk: 10240,
            Ports: new List<GamePortDto>
            {
                new("Game Port", 25565, "tcp/udp", true, "Main game connection port"),
                new("RCON Port", 25575, "tcp", false, "Remote console port")
            },
            Variables: new List<GameVariableDto>
            {
                new("Server Type", "SERVER_TYPE", "paper", "select", "Server software type", true, 
                    new List<string> { "paper", "vanilla", "spigot" }, null),
                new("Minecraft Version", "MC_VERSION", "1.21.1", "text", "Minecraft version to run", true, null, @"^\d+\.\d+(\.\d+)?$"),
                new("Server Name", "SERVER_NAME", "My Minecraft Server", "text", "Display name of your server", true, null, null),
                new("MOTD", "MOTD", "A Minecraft Server", "text", "Message shown in server list", false, null, null),
                new("Max Players", "MAX_PLAYERS", "20", "number", "Maximum concurrent players", true, null, null),
                new("Game Mode", "GAMEMODE", "survival", "select", "Default game mode", true,
                    new List<string> { "survival", "creative", "adventure", "spectator" }, null),
                new("Difficulty", "DIFFICULTY", "normal", "select", "World difficulty", true,
                    new List<string> { "peaceful", "easy", "normal", "hard" }, null),
                new("View Distance", "VIEW_DISTANCE", "10", "number", "Render distance in chunks", false, null, null),
                new("Online Mode", "ONLINE_MODE", "true", "boolean", "Verify player accounts with Mojang", true, null, null),
                new("Maximum RAM", "MAX_RAM", "2G", "text", "Maximum memory allocation", true, null, @"^\d+[GMK]$"),
                new("Minimum RAM", "MIN_RAM", "1G", "text", "Minimum memory allocation", true, null, @"^\d+[GMK]$"),
                new("Enable RCON", "ENABLE_RCON", "true", "boolean", "Enable remote console", false, null, null),
                new("RCON Password", "RCON_PASSWORD", "", "password", "Password for RCON access", false, null, null),
                new("Operators", "OPS", "", "text", "Comma-separated list of operator usernames", false, null, null),
                new("World Name", "LEVEL_NAME", "world", "text", "Name of the world folder", false, null, null),
                new("World Seed", "LEVEL_SEED", "", "text", "World generation seed", false, null, null),
                new("Level Type", "LEVEL_TYPE", "default", "select", "World generation type", false,
                    new List<string> { "default", "flat", "largeBiomes", "amplified" }, null)
            },
            Notes: "First startup downloads server JAR automatically. Paper is recommended for best performance."
        ),

        // Minecraft Bedrock Edition
        new GameTemplateDto(
            Id: "minecraft-bedrock",
            Name: "Minecraft Bedrock Edition",
            Description: "Official Bedrock Dedicated Server for cross-platform play (PC, Xbox, Mobile)",
            Icon: "🪨",
            Category: "Minecraft",
            DockerImage: "arcadenode/minecraft-bedrock:latest",
            DefaultMemory: 1024,
            DefaultCpu: 100,
            DefaultDisk: 5120,
            Ports: new List<GamePortDto>
            {
                new("Game Port (IPv4)", 19132, "udp", true, "Main game port"),
                new("Game Port (IPv6)", 19133, "udp", false, "IPv6 game port")
            },
            Variables: new List<GameVariableDto>
            {
                new("Server Version", "VERSION", "LATEST", "text", "BDS version (LATEST or specific)", true, null, null),
                new("Server Name", "SERVER_NAME", "Bedrock Server", "text", "Display name of your server", true, null, null),
                new("Max Players", "MAX_PLAYERS", "10", "number", "Maximum concurrent players", true, null, null),
                new("Game Mode", "GAMEMODE", "survival", "select", "Default game mode", true,
                    new List<string> { "survival", "creative", "adventure" }, null),
                new("Difficulty", "DIFFICULTY", "normal", "select", "World difficulty", true,
                    new List<string> { "peaceful", "easy", "normal", "hard" }, null),
                new("View Distance", "VIEW_DISTANCE", "32", "number", "Render distance in chunks (5-32)", false, null, null),
                new("Tick Distance", "TICK_DISTANCE", "4", "number", "Simulation distance (4-12)", false, null, null),
                new("Online Mode", "ONLINE_MODE", "true", "boolean", "Require Xbox Live authentication", true, null, null),
                new("Level Name", "LEVEL_NAME", "Bedrock level", "text", "World name", false, null, null),
                new("Level Seed", "LEVEL_SEED", "", "text", "World generation seed", false, null, null),
                new("Allow List", "WHITE_LIST", "false", "boolean", "Enable player allowlist", false, null, null),
                new("Allowed Players", "ALLOW_LIST_USERS", "", "text", "Comma-separated Xbox Gamertags", false, null, null),
                new("Operators", "OPS", "", "text", "Comma-separated operator XUIDs", false, null, null),
                new("Anti-Cheat Mode", "SERVER_AUTHORITATIVE_MOVEMENT", "server-auth", "select", "Movement validation mode", false,
                    new List<string> { "client-auth", "server-auth", "server-auth-with-rewind" }, null)
            },
            Notes: "First startup downloads the official Bedrock Dedicated Server. Supports Xbox, Windows 10, iOS, Android players."
        ),

        // Project Zomboid
        new GameTemplateDto(
            Id: "project-zomboid",
            Name: "Project Zomboid",
            Description: "Multiplayer zombie survival server with Steam Workshop mod support",
            Icon: "🧟",
            Category: "Survival",
            DockerImage: "arcadenode/project-zomboid:latest",
            DefaultMemory: 4096,
            DefaultCpu: 200,
            DefaultDisk: 20480,
            Ports: new List<GamePortDto>
            {
                new("Game Port", 16261, "udp", true, "Main game port"),
                new("Direct Port", 16262, "udp", true, "Direct connection port"),
                new("RCON Port", 27015, "tcp", false, "Remote console port")
            },
            Variables: new List<GameVariableDto>
            {
                new("Server Name", "SERVER_NAME", "ArcadeNode PZ Server", "text", "Display name in server browser", true, null, null),
                new("Server Password", "SERVER_PASSWORD", "", "password", "Password to join (empty for public)", false, null, null),
                new("Admin Password", "ADMIN_PASSWORD", "", "password", "Administrator password (required)", true, null, null),
                new("Max Players", "MAX_PLAYERS", "16", "number", "Maximum concurrent players", true, null, null),
                new("Max RAM (MB)", "MAX_RAM", "4096", "number", "Memory allocation in MB", true, null, null),
                new("Beta Branch", "BETA_BRANCH", "", "select", "Use a beta/unstable version of the server", false,
                    new List<string> { "", "unstable", "iwbums", "b42mp" }, null),
                new("Beta Password", "BETA_PASSWORD", "", "password", "Password for private beta branches (if required)", false, null, null),
                new("Enable PvP", "PVP", "true", "boolean", "Allow player vs player combat", false, null, null),
                new("Pause When Empty", "PAUSE_EMPTY", "true", "boolean", "Pause server when no players online", false, null, null),
                new("Map", "MAP", "Muldraugh, KY", "text", "Starting map location", false, null, null),
                new("Workshop Mod IDs", "WORKSHOP_IDS", "", "text", "Comma-separated Steam Workshop IDs", false, null, null),
                new("Mod IDs", "MOD_IDS", "", "text", "Comma-separated mod folder names", false, null, null),
                new("Zombie Population", "ZOMBIE_COUNT", "1.0", "select", "Zombie spawn multiplier", false,
                    new List<string> { "0", "0.25", "0.5", "1.0", "2.0", "3.0", "4.0" }, null)
            },
            Notes: "⚠️ First startup downloads ~3GB via SteamCMD (10-15 minutes). Supports Steam Workshop mods."
        ),

        // Arma Reforger
        new GameTemplateDto(
            Id: "arma-reforger",
            Name: "Arma Reforger",
            Description: "Military simulation dedicated server with scenario and mod support",
            Icon: "🎖️",
            Category: "Military Sim",
            DockerImage: "arcadenode/arma-reforger:latest",
            DefaultMemory: 8192,
            DefaultCpu: 200,
            DefaultDisk: 30720,
            Ports: new List<GamePortDto>
            {
                new("Game Port", 2001, "udp", true, "Main game port"),
                new("Steam Query Port", 17777, "udp", true, "Server browser query port")
            },
            Variables: new List<GameVariableDto>
            {
                new("Server Name", "SERVER_NAME", "ArcadeNode Reforger", "text", "Display name in server browser", true, null, null),
                new("Server Password", "SERVER_PASSWORD", "", "password", "Password to join (empty for public)", false, null, null),
                new("Admin Password", "ADMIN_PASSWORD", "", "password", "Administrator password (required)", true, null, null),
                new("Max Players", "MAX_PLAYERS", "64", "number", "Maximum concurrent players", true, null, null),
                new("Scenario", "SCENARIO_ID", "{ECC61978EDCC2B5A}Missions/23_Campaign.conf", "select", "Mission scenario", true,
                    new List<string>
                    {
                        "{ECC61978EDCC2B5A}Missions/23_Campaign.conf",
                        "{59AD59368755F41A}Missions/21_GM_Eden.conf",
                        "{28802845ADA64D52}Missions/22_GM_Arland.conf"
                    }, null),
                new("Enable Crossplay", "CROSSPLATFORM", "true", "boolean", "Allow Xbox players", true, null, null),
                new("Enable BattlEye", "BATTLYE", "true", "boolean", "BattlEye anti-cheat", true, null, null),
                new("Disable Third Person", "DISABLE_THIRD_PERSON", "false", "boolean", "Force first-person view", false, null, null),
                new("Server Max FPS", "SERVER_MAX_FPS", "60", "number", "Server tick rate", false, null, null),
                new("Network View Distance", "NETWORK_VIEW_DISTANCE", "2500", "number", "Network streaming distance", false, null, null),
                new("Mod IDs", "MODS", "", "text", "Comma-separated mod IDs", false, null, null)
            },
            Notes: "⚠️ First startup downloads ~7GB via SteamCMD (15-20 minutes). Requires Steam account for download."
        )
    };

    public IEnumerable<GameTemplateDto> GetAllTemplates() => _templates;

    public GameTemplateDto? GetTemplateById(string id) =>
        _templates.FirstOrDefault(t => t.Id.Equals(id, StringComparison.OrdinalIgnoreCase));

    public IEnumerable<GameTemplateDto> GetTemplatesByCategory(string category) =>
        _templates.Where(t => t.Category.Equals(category, StringComparison.OrdinalIgnoreCase));
}
