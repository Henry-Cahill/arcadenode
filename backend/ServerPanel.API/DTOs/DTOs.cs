using ServerPanel.API.Models;
using ServerPanel.API.Validation;
using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.DTOs;

// Auth DTOs
public record LoginRequest(
    [Required] string Username,
    [Required] string Password
);

public record RegisterRequest(
    [Required][MaxLength(100)] string Username,
    [Required][EmailAddress] string Email,
    [Required][PasswordComplexity] string Password,
    [Required] string InviteCode,
    string? FirstName,
    string? LastName
);

public record AuthResponse(
    string Token,
    UserDto User,
    DateTime ExpiresAt
);

public record UserDto(
    Guid Id,
    string Username,
    string Email,
    string FirstName,
    string LastName,
    UserRole Role,
    bool IsActive,
    DateTime CreatedAt,
    DateTime? LastLoginAt
);

// Server DTOs
public record CreateServerRequest(
    [Required][MaxLength(100)] string Name,
    string? Description,
    [Required] Guid NodeId,
    Guid? EggId,
    [Required] string DockerImage,
    string? StartupCommand,
    [Range(128, 1048576)] int MemoryLimit = 1024,
    [Range(1, 6400)] int CpuLimit = 100,
    [Range(256, 10485760)] int DiskLimit = 10240,
    [Range(1, 65535)] int Port = 25565,
    Dictionary<string, string>? EnvironmentVariables = null
);

public record UpdateServerRequest(
    string? Name,
    string? Description,
    string? StartupCommand,
    int? MemoryLimit,
    int? CpuLimit,
    int? DiskLimit,
    Dictionary<string, string>? EnvironmentVariables
);

public record ServerDto(
    Guid Id,
    string Name,
    string Description,
    string Identifier,
    string? ContainerId,
    string DockerImage,
    string? StartupCommand,
    int MemoryLimit,
    int CpuLimit,
    int DiskLimit,
    int Port,
    string IpAddress,
    ServerStatus Status,
    bool IsSuspended,
    DateTime CreatedAt,
    DateTime? LastStartedAt,
    Guid OwnerId,
    string OwnerUsername,
    Guid NodeId,
    string NodeName
);

public record ServerStatsDto(
    Guid ServerId,
    ServerStatus Status,
    long MemoryUsage,
    double CpuUsage,
    long DiskUsage,
    long NetworkRxBytes,
    long NetworkTxBytes,
    DateTime Timestamp
);

// Node DTOs
public record CreateNodeRequest(
    [Required][MaxLength(100)] string Name,
    string? Description,
    [Required][MaxLength(255)] string Fqdn,
    [Range(1, 65535)] int? DaemonPort = 8080,
    [Range(1, 65535)] int? SftpPort = 2022,
    bool? UseSsl = false,
    bool? BehindProxy = false,
    [Range(0, int.MaxValue)] int? TotalMemory = 0,
    [Range(0, int.MaxValue)] int? TotalDisk = 0,
    [Range(0, 100)] int? MemoryOverallocate = 0,
    [Range(0, 100)] int? DiskOverallocate = 0,
    string? DockerEndpoint = "tcp://node:2375"
);

public record UpdateNodeRequest(
    string? Name,
    string? Description,
    string? Fqdn,
    int? DaemonPort,
    int? SftpPort,
    bool? UseSsl,
    int? TotalMemory,
    int? TotalDisk,
    int? MemoryOverallocate,
    int? DiskOverallocate
);

public record NodeDto(
    Guid Id,
    string Name,
    string Description,
    string Fqdn,
    int DaemonPort,
    int SftpPort,
    bool UseSsl,
    bool BehindProxy,
    string DockerEndpoint,
    int TotalMemory,
    int TotalDisk,
    int AllocatedMemory,
    int AllocatedDisk,
    bool IsOnline,
    bool IsMaintenanceMode,
    int ServerCount,
    DateTime CreatedAt,
    DateTime? LastCheckedAt
);

public record CreateAllocationBulkRequest(string IpAddress, int StartPort, int? EndPort, string? Alias);

// Nest and Egg DTOs
public record NestDto(
    Guid Id,
    string Name,
    string Description,
    string Author,
    int EggCount,
    DateTime CreatedAt
);

public record EggDto(
    Guid Id,
    string Name,
    string Description,
    string DockerImage,
    string StartupCommand,
    Guid NestId,
    string NestName,
    List<EggVariableDto>? Variables,
    DateTime CreatedAt
);

public record EggVariableDto(
    string Name,
    string Description,
    string EnvVariable,
    string DefaultValue,
    bool UserViewable,
    bool UserEditable,
    string? Rules
);

// Allocation DTOs
public record CreateAllocationRequest(
    [Required] Guid NodeId,
    [Required] string IpAddress,
    [Required] int StartPort,
    int? EndPort,
    string? Alias
);

public record AllocationDto(
    Guid Id,
    string IpAddress,
    int Port,
    string? Alias,
    bool IsAssigned,
    Guid NodeId,
    Guid? ServerId,
    string? ServerName
);

// Node Connection Test
public record NodeConnectionTestResult(
    bool Success,
    string Message,
    string? DockerVersion,
    string? OperatingSystem,
    int? ContainerCount,
    long? MemoryTotal,
    long? MemoryAvailable
);

public record TestNodeConnectionRequest(
    [Required] string DockerEndpoint
);

// Backup DTOs
public record CreateBackupRequest(
    [Required] string Name,
    List<string>? IgnoredFiles,
    bool IsLocked = false
);

public record BackupDto(
    Guid Id,
    string Name,
    long Size,
    string? Checksum,
    bool IsSuccessful,
    bool IsLocked,
    DateTime? CompletedAt,
    DateTime CreatedAt
);

// Power Action
public record PowerActionRequest(
    [Required] string Action // start, stop, restart, kill
);

// Console
public record ConsoleCommandRequest(
    [Required] string Command
);

// Cartridge-based Server Creation
public record CreateCartridgeServerRequest(
    [Required][MaxLength(100)] string Name,
    string? Description,
    [Required] Guid NodeId,
    [Required] string CartridgeId,
    int MemoryLimit = 2048,
    int CpuLimit = 100,
    int DiskLimit = 10240,
    int? Port = null,  // If null, auto-assign
    Dictionary<string, object>? Variables = null  // User-provided variable values (optional)
);

// Invite Code DTOs
public record CreateInviteCodeRequest(
    int MaxUses = 1,
    DateTime? ExpiresAt = null
);

public record InviteCodeDto(
    Guid Id,
    string Code,
    int MaxUses,
    int TimesUsed,
    DateTime? ExpiresAt,
    bool IsRevoked,
    bool IsValid,
    DateTime CreatedAt,
    string CreatedByUsername
);
