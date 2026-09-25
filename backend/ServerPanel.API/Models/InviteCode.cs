using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.Models;

public class InviteCode
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string Code { get; set; } = string.Empty;

    /// <summary>
    /// Maximum number of times this code can be used. 0 = unlimited.
    /// </summary>
    public int MaxUses { get; set; } = 1;

    /// <summary>
    /// How many times this code has been used so far.
    /// </summary>
    public int TimesUsed { get; set; } = 0;

    /// <summary>
    /// Optional expiration date. Null = never expires.
    /// </summary>
    public DateTime? ExpiresAt { get; set; }

    public bool IsRevoked { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// The admin who created this invite code.
    /// </summary>
    public Guid CreatedByUserId { get; set; }
    public User? CreatedByUser { get; set; }

    /// <summary>
    /// Check whether this invite code is currently valid for use.
    /// </summary>
    public bool IsValid =>
        !IsRevoked
        && (MaxUses == 0 || TimesUsed < MaxUses)
        && (ExpiresAt == null || ExpiresAt > DateTime.UtcNow);
}
