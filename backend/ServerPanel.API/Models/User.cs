using System.ComponentModel.DataAnnotations;

namespace ServerPanel.API.Models;

public class User
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Username { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    [MaxLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string PasswordHash { get; set; } = string.Empty;

    [MaxLength(50)]
    public string FirstName { get; set; } = string.Empty;

    [MaxLength(50)]
    public string LastName { get; set; } = string.Empty;

    public UserRole Role { get; set; } = UserRole.User;

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? LastLoginAt { get; set; }

    public int FailedLoginAttempts { get; set; } = 0;

    public DateTime? LockoutEnd { get; set; }

    // Navigation properties
    public ICollection<GameServer> Servers { get; set; } = new List<GameServer>();
    public ICollection<ApiKey> ApiKeys { get; set; } = new List<ApiKey>();
}

public enum UserRole
{
    User = 0,
    SubUser = 1,
    Admin = 2,
    SuperAdmin = 3
}
