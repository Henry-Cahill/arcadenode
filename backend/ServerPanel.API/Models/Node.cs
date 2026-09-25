using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.Models;

public class Node
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    public string Fqdn { get; set; } = string.Empty; // Fully Qualified Domain Name

    [Required]
    public int DaemonPort { get; set; } = 8080;

    [Required]
    public int SftpPort { get; set; } = 2022;

    public bool UseSsl { get; set; } = false;

    public bool BehindProxy { get; set; } = false;

    // Resource Configuration
    public int TotalMemory { get; set; } = 0; // MB (0 = unlimited)

    public int TotalDisk { get; set; } = 0; // MB (0 = unlimited)

    public int MemoryOverallocate { get; set; } = 0; // Percentage

    public int DiskOverallocate { get; set; } = 0; // Percentage

    // Docker Configuration
    [Required]
    public string DockerEndpoint { get; set; } = "unix:///var/run/docker.sock";

    public string? DaemonToken { get; set; }

    // Status
    public bool IsOnline { get; set; } = false;

    public bool IsMaintenanceMode { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? LastCheckedAt { get; set; }

    // Navigation
    public ICollection<GameServer> Servers { get; set; } = new List<GameServer>();
    public ICollection<Allocation> Allocations { get; set; } = new List<Allocation>();

    // Calculated properties
    public int AllocatedMemory => Servers.Sum(s => s.MemoryLimit);
    public int AllocatedDisk => Servers.Sum(s => s.DiskLimit);
    public int ServerCount => Servers.Count;
}
