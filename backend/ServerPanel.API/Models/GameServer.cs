using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ServerPanel.API.Models;

public class GameServer
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public string Identifier { get; set; } = string.Empty;

    // Docker Configuration
    public string? ContainerId { get; set; }

    [Required]
    public string DockerImage { get; set; } = string.Empty;

    public string? StartupCommand { get; set; }

    public string? EnvironmentVariables { get; set; } // JSON string

    // Resource Limits
    public int MemoryLimit { get; set; } = 1024; // MB

    public int CpuLimit { get; set; } = 100; // Percentage (100 = 1 core)

    public int DiskLimit { get; set; } = 10240; // MB

    // Network
    public int Port { get; set; }

    public string? AdditionalPorts { get; set; } // JSON array of extra ports

    [MaxLength(50)]
    public string IpAddress { get; set; } = "0.0.0.0";

    // Status
    public ServerStatus Status { get; set; } = ServerStatus.Stopped;

    public bool IsSuspended { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? LastStartedAt { get; set; }

    // Foreign Keys
    [Required]
    public Guid OwnerId { get; set; }

    [ForeignKey("OwnerId")]
    public User Owner { get; set; } = null!;

    [Required]
    public Guid NodeId { get; set; }

    [ForeignKey("NodeId")]
    public Node Node { get; set; } = null!;

    public Guid? EggId { get; set; }

    [ForeignKey("EggId")]
    public Egg? Egg { get; set; }

    // Navigation
    public ICollection<Allocation> Allocations { get; set; } = new List<Allocation>();
    public ICollection<Backup> Backups { get; set; } = new List<Backup>();
    public ICollection<Schedule> Schedules { get; set; } = new List<Schedule>();
}

public enum ServerStatus
{
    Stopped = 0,
    Starting = 1,
    Running = 2,
    Stopping = 3,
    Error = 4,
    Installing = 5,
    Suspended = 6
}
