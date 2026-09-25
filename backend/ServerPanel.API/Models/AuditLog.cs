using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.Models;

/// <summary>
/// Immutable record of a state-changing HTTP request, used as an administrative
/// audit trail. UserId is kept as a loose reference (no FK) so history survives
/// user deletion. Request/response bodies are intentionally never stored.
/// </summary>
public class AuditLog
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    public Guid? UserId { get; set; }

    [MaxLength(100)]
    public string? Username { get; set; }

    [Required]
    [MaxLength(10)]
    public string Method { get; set; } = string.Empty;

    [Required]
    [MaxLength(2048)]
    public string Path { get; set; } = string.Empty;

    public int StatusCode { get; set; }

    [MaxLength(45)]
    public string? IpAddress { get; set; }

    [MaxLength(512)]
    public string? UserAgent { get; set; }

    public long DurationMs { get; set; }
}
