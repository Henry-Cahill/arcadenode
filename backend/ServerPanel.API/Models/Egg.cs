using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ServerPanel.API.Models;

public class Egg
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required]
    public string DockerImage { get; set; } = string.Empty;

    public string? DockerImages { get; set; } // JSON array of available images

    [Required]
    public string StartupCommand { get; set; } = string.Empty;

    public string? ConfigFiles { get; set; } // JSON for config file parsing

    public string? ConfigStartup { get; set; } // JSON for startup config

    public string? ConfigStop { get; set; } // Stop command

    public string? Variables { get; set; } // JSON array of EggVariable

    public string? InstallScript { get; set; } // Bash install script

    public string? InstallContainer { get; set; } // Docker image for installation

    public string? InstallEntrypoint { get; set; }

    // Nest/Category
    [Required]
    public Guid NestId { get; set; }

    [ForeignKey("NestId")]
    public Nest Nest { get; set; } = null!;

    public string? CopyFrom { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public ICollection<GameServer> Servers { get; set; } = new List<GameServer>();
}

public class EggVariable
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string EnvVariable { get; set; } = string.Empty;
    public string DefaultValue { get; set; } = string.Empty;
    public bool UserViewable { get; set; } = true;
    public bool UserEditable { get; set; } = true;
    public string? Rules { get; set; } // Validation rules
}
