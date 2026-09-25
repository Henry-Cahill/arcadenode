using System.Text.Json.Serialization;

namespace ServerPanel.API.Models;

/// <summary>
/// Represents a game server cartridge definition loaded from cartridge.json
/// </summary>
public class Cartridge
{
    [JsonPropertyName("$schema")]
    public string? Schema { get; set; }

    [JsonPropertyName("meta")]
    public CartridgeMeta Meta { get; set; } = new();

    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("author")]
    public string Author { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("tags")]
    public List<string> Tags { get; set; } = new();

    [JsonPropertyName("website")]
    public string? Website { get; set; }

    [JsonPropertyName("icon")]
    public string? Icon { get; set; }

    [JsonPropertyName("docker")]
    public CartridgeDocker Docker { get; set; } = new();

    [JsonPropertyName("ports")]
    public Dictionary<string, CartridgePort> Ports { get; set; } = new();

    [JsonPropertyName("resources")]
    public CartridgeResources Resources { get; set; } = new();

    [JsonPropertyName("startup")]
    public CartridgeStartup Startup { get; set; } = new();

    [JsonPropertyName("process")]
    public CartridgeProcess Process { get; set; } = new();

    [JsonPropertyName("installation")]
    public CartridgeInstallation Installation { get; set; } = new();

    [JsonPropertyName("directories")]
    public Dictionary<string, CartridgeDirectory>? Directories { get; set; }

    [JsonPropertyName("config_files")]
    public Dictionary<string, CartridgeConfigFile>? ConfigFiles { get; set; }

    [JsonPropertyName("variables")]
    public List<CartridgeVariable> Variables { get; set; } = new();

    [JsonPropertyName("system_variables")]
    public Dictionary<string, string>? SystemVariables { get; set; }

    [JsonPropertyName("variable_groups")]
    public List<CartridgeVariableGroup>? VariableGroups { get; set; }

    [JsonPropertyName("volumes")]
    public Dictionary<string, CartridgeVolume>? Volumes { get; set; }

    [JsonPropertyName("health_check")]
    public CartridgeHealthCheck? HealthCheck { get; set; }

    [JsonPropertyName("backup")]
    public CartridgeBackup? Backup { get; set; }

    [JsonPropertyName("console")]
    public CartridgeConsole? Console { get; set; }

    [JsonPropertyName("updates")]
    public CartridgeUpdates? Updates { get; set; }

    [JsonPropertyName("logs")]
    public CartridgeLogs? Logs { get; set; }
}

public class CartridgeMeta
{
    [JsonPropertyName("version")]
    public string Version { get; set; } = "1.0";

    [JsonPropertyName("format")]
    public string Format { get; set; } = "ARCADENODE_V1";

    [JsonPropertyName("exported_at")]
    public string? ExportedAt { get; set; }
}

public class CartridgeDocker
{
    [JsonPropertyName("image")]
    public string Image { get; set; } = string.Empty;

    [JsonPropertyName("build")]
    public CartridgeDockerBuild? Build { get; set; }

    [JsonPropertyName("base_image")]
    public string? BaseImage { get; set; }
}

public class CartridgeDockerBuild
{
    [JsonPropertyName("dockerfile")]
    public string Dockerfile { get; set; } = "Dockerfile";

    [JsonPropertyName("context")]
    public string Context { get; set; } = ".";
}

public class CartridgePort
{
    [JsonPropertyName("default")]
    public int Default { get; set; }

    [JsonPropertyName("protocol")]
    public string Protocol { get; set; } = "tcp";

    [JsonPropertyName("required")]
    public bool Required { get; set; } = true;

    [JsonPropertyName("description")]
    public string? Description { get; set; }
}

public class CartridgeResources
{
    [JsonPropertyName("memory")]
    public CartridgeResourceLimit Memory { get; set; } = new();

    [JsonPropertyName("cpu")]
    public CartridgeResourceLimit Cpu { get; set; } = new();

    [JsonPropertyName("disk")]
    public CartridgeResourceLimit? Disk { get; set; }
}

public class CartridgeResourceLimit
{
    [JsonPropertyName("minimum")]
    public int Minimum { get; set; }

    [JsonPropertyName("recommended")]
    public int Recommended { get; set; }

    [JsonPropertyName("maximum")]
    public int Maximum { get; set; }

    [JsonPropertyName("unit")]
    public string? Unit { get; set; }
}

public class CartridgeStartup
{
    [JsonPropertyName("command")]
    public string Command { get; set; } = string.Empty;

    [JsonPropertyName("working_directory")]
    public string? WorkingDirectory { get; set; }

    [JsonPropertyName("ready_pattern")]
    public string? ReadyPattern { get; set; }

    [JsonPropertyName("ready_timeout")]
    public int ReadyTimeout { get; set; } = 120;

    [JsonPropertyName("environment")]
    public Dictionary<string, string>? Environment { get; set; }
}

public class CartridgeProcess
{
    [JsonPropertyName("stop_command")]
    public string StopCommand { get; set; } = "stop";

    [JsonPropertyName("stop_timeout")]
    public int StopTimeout { get; set; } = 30;

    [JsonPropertyName("restart_on_crash")]
    public bool RestartOnCrash { get; set; } = true;

    [JsonPropertyName("crash_patterns")]
    public List<string>? CrashPatterns { get; set; }
}

public class CartridgeInstallation
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "steamcmd";

    [JsonPropertyName("app_id")]
    public int? AppId { get; set; }

    [JsonPropertyName("anonymous")]
    public bool Anonymous { get; set; } = true;

    [JsonPropertyName("validate")]
    public bool Validate { get; set; } = true;

    [JsonPropertyName("platform")]
    public string? Platform { get; set; }

    [JsonPropertyName("beta")]
    public CartridgeInstallationBeta? Beta { get; set; }

    [JsonPropertyName("post_install")]
    public List<string>? PostInstall { get; set; }

    [JsonPropertyName("sources")]
    public Dictionary<string, CartridgeInstallationSource>? Sources { get; set; }
}

public class CartridgeInstallationBeta
{
    [JsonPropertyName("branch_variable")]
    public string? BranchVariable { get; set; }

    [JsonPropertyName("password_variable")]
    public string? PasswordVariable { get; set; }
}

public class CartridgeInstallationSource
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("api")]
    public string? Api { get; set; }

    [JsonPropertyName("manifest")]
    public string? Manifest { get; set; }
}

public class CartridgeDirectory
{
    [JsonPropertyName("path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("volume")]
    public bool Volume { get; set; } = false;
}

public class CartridgeConfigFile
{
    [JsonPropertyName("parser")]
    public string Parser { get; set; } = "properties";

    [JsonPropertyName("template")]
    public string? Template { get; set; }

    [JsonPropertyName("location")]
    public string Location { get; set; } = string.Empty;

    [JsonPropertyName("generate_if_missing")]
    public bool GenerateIfMissing { get; set; } = true;

    [JsonPropertyName("mappings")]
    public Dictionary<string, string>? Mappings { get; set; }
}

public class CartridgeVariable
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("env_variable")]
    public string EnvVariable { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "string";

    [JsonPropertyName("default")]
    public object? Default { get; set; }

    [JsonPropertyName("required")]
    public bool Required { get; set; } = false;

    [JsonPropertyName("user_viewable")]
    public bool UserViewable { get; set; } = true;

    [JsonPropertyName("user_editable")]
    public bool UserEditable { get; set; } = true;

    [JsonPropertyName("validation")]
    public CartridgeVariableValidation? Validation { get; set; }

    [JsonPropertyName("ui")]
    public CartridgeVariableUI? UI { get; set; }
}

public class CartridgeVariableValidation
{
    [JsonPropertyName("min")]
    public int? Min { get; set; }

    [JsonPropertyName("max")]
    public int? Max { get; set; }

    [JsonPropertyName("min_length")]
    public int? MinLength { get; set; }

    [JsonPropertyName("max_length")]
    public int? MaxLength { get; set; }

    [JsonPropertyName("pattern")]
    public string? Pattern { get; set; }
}

public class CartridgeVariableUI
{
    [JsonPropertyName("component")]
    public string Component { get; set; } = "text";

    [JsonPropertyName("placeholder")]
    public string? Placeholder { get; set; }

    [JsonPropertyName("group")]
    public string? Group { get; set; }

    [JsonPropertyName("help")]
    public string? Help { get; set; }

    [JsonPropertyName("options")]
    public List<CartridgeSelectOption>? Options { get; set; }

    [JsonPropertyName("step")]
    public int? Step { get; set; }

    [JsonPropertyName("marks")]
    public List<int>? Marks { get; set; }

    [JsonPropertyName("rows")]
    public int? Rows { get; set; }

    [JsonPropertyName("prefix")]
    public string? Prefix { get; set; }

    [JsonPropertyName("suffix")]
    public string? Suffix { get; set; }

    [JsonPropertyName("on_label")]
    public string? OnLabel { get; set; }

    [JsonPropertyName("off_label")]
    public string? OffLabel { get; set; }
}

public class CartridgeSelectOption
{
    [JsonPropertyName("value")]
    public string Value { get; set; } = string.Empty;

    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;
}

public class CartridgeVariableGroup
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("order")]
    public int Order { get; set; } = 0;

    [JsonPropertyName("collapsed")]
    public bool Collapsed { get; set; } = false;

    [JsonPropertyName("admin_only")]
    public bool AdminOnly { get; set; } = false;
}

public class CartridgeVolume
{
    [JsonPropertyName("container_path")]
    public string ContainerPath { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("required")]
    public bool Required { get; set; } = true;

    [JsonPropertyName("backup")]
    public bool Backup { get; set; } = true;
}

public class CartridgeHealthCheck
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "tcp";

    [JsonPropertyName("port")]
    public string Port { get; set; } = string.Empty;

    [JsonPropertyName("interval")]
    public int Interval { get; set; } = 30;

    [JsonPropertyName("timeout")]
    public int Timeout { get; set; } = 10;

    [JsonPropertyName("start_period")]
    public int StartPeriod { get; set; } = 120;

    [JsonPropertyName("retries")]
    public int Retries { get; set; } = 3;
}

public class CartridgeBackup
{
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; } = true;

    [JsonPropertyName("paths")]
    public List<string> Paths { get; set; } = new();

    [JsonPropertyName("exclude")]
    public List<string>? Exclude { get; set; }

    [JsonPropertyName("schedule")]
    public string? Schedule { get; set; }

    [JsonPropertyName("retention")]
    public int Retention { get; set; } = 7;
}

public class CartridgeConsole
{
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; } = true;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "stdin";

    [JsonPropertyName("commands")]
    public Dictionary<string, CartridgeConsoleCommand>? Commands { get; set; }
}

public class CartridgeConsoleCommand
{
    [JsonPropertyName("command")]
    public string Command { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("parameters")]
    public List<CartridgeCommandParameter>? Parameters { get; set; }
}

public class CartridgeCommandParameter
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = "string";

    [JsonPropertyName("required")]
    public bool Required { get; set; } = true;

    [JsonPropertyName("default")]
    public object? Default { get; set; }

    [JsonPropertyName("options")]
    public List<string>? Options { get; set; }
}

public class CartridgeUpdates
{
    [JsonPropertyName("auto_update")]
    public bool AutoUpdate { get; set; } = false;

    [JsonPropertyName("check_on_start")]
    public bool CheckOnStart { get; set; } = true;

    [JsonPropertyName("method")]
    public string Method { get; set; } = "steamcmd";
}

public class CartridgeLogs
{
    [JsonPropertyName("files")]
    public List<CartridgeLogFile>? Files { get; set; }

    [JsonPropertyName("docker_logs")]
    public bool DockerLogs { get; set; } = true;
}

public class CartridgeLogFile
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("tail")]
    public bool Tail { get; set; } = false;
}
