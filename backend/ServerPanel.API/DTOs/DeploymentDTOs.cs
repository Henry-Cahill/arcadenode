using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.DTOs;

// Game Template DTOs for deployment wizards
public record GameTemplateDto(
    string Id,
    string Name,
    string Description,
    string Icon,
    string Category,
    string DockerImage,
    int DefaultMemory,
    int DefaultCpu,
    int DefaultDisk,
    List<GamePortDto> Ports,
    List<GameVariableDto> Variables,
    string? Notes
);

public record GamePortDto(
    string Name,
    int DefaultPort,
    string Protocol,
    bool Required,
    string Description
);

public record GameVariableDto(
    string Name,
    string EnvVariable,
    string DefaultValue,
    string Type, // text, password, number, select, boolean
    string Description,
    bool Required,
    List<string>? Options, // For select type
    string? Validation // regex pattern
);

// Deployment Wizard DTOs
public record DeployServerRequest(
    [Required] string GameTemplateId,
    [Required][MaxLength(100)] string ServerName,
    string? Description,
    [Required] Guid NodeId,
    int? MemoryLimit,
    int? CpuLimit,
    int? DiskLimit,
    Dictionary<int, int>? PortMappings, // container port -> host port
    [Required] Dictionary<string, string> Variables
);

public record DeploymentProgressDto(
    Guid DeploymentId,
    string Status, // pending, pulling_image, creating_container, configuring, starting, complete, failed
    int Progress, // 0-100
    string? CurrentStep,
    string? ErrorMessage,
    Guid? ServerId
);

public record QuickDeployRequest(
    [Required] string GameTemplateId,
    [Required] string ServerName,
    [Required] Guid NodeId,
    Dictionary<string, string>? OverrideVariables
);
