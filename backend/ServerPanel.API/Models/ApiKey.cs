using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ServerPanel.API.Models;

public class ApiKey
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Identifier { get; set; } = string.Empty;

    [Required]
    public string Token { get; set; } = string.Empty;

    [MaxLength(500)]
    public string? Description { get; set; }

    public string? AllowedIps { get; set; } // JSON array

    public string? Permissions { get; set; } // JSON array

    public DateTime? LastUsedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Foreign Keys
    [Required]
    public Guid UserId { get; set; }

    [ForeignKey("UserId")]
    public User User { get; set; } = null!;
}
