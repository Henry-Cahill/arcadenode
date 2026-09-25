using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ServerPanel.API.Models;

public class Backup
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public string? IgnoredFiles { get; set; } // JSON array

    public long Size { get; set; } = 0; // Bytes

    public string? Checksum { get; set; }

    public bool IsSuccessful { get; set; } = false;

    public bool IsLocked { get; set; } = false;

    public DateTime? CompletedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Foreign Keys
    [Required]
    public Guid ServerId { get; set; }

    [ForeignKey("ServerId")]
    public GameServer Server { get; set; } = null!;
}

public class Schedule
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    public string CronExpression { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    public bool IsProcessing { get; set; } = false;

    public bool OnlyWhenOnline { get; set; } = false;

    public DateTime? LastRunAt { get; set; }

    public DateTime? NextRunAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Foreign Keys
    [Required]
    public Guid ServerId { get; set; }

    [ForeignKey("ServerId")]
    public GameServer Server { get; set; } = null!;

    // Navigation
    public ICollection<ScheduleTask> Tasks { get; set; } = new List<ScheduleTask>();
}

public class ScheduleTask
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public int SequenceId { get; set; } = 1;

    [Required]
    public TaskAction Action { get; set; }

    public string? Payload { get; set; }

    public int TimeOffset { get; set; } = 0; // Seconds

    public bool ContinueOnFailure { get; set; } = false;

    // Foreign Keys
    [Required]
    public Guid ScheduleId { get; set; }

    [ForeignKey("ScheduleId")]
    public Schedule Schedule { get; set; } = null!;
}

public enum TaskAction
{
    Command = 0,
    Power = 1,
    Backup = 2
}
