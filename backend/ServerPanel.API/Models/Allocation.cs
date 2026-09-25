using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ServerPanel.API.Models;

public class Allocation
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(50)]
    public string IpAddress { get; set; } = string.Empty;

    [Required]
    public int Port { get; set; }

    [MaxLength(100)]
    public string? Alias { get; set; }

    public string? Notes { get; set; }

    public bool IsAssigned { get; set; } = false;

    // Foreign Keys
    [Required]
    public Guid NodeId { get; set; }

    [ForeignKey("NodeId")]
    public Node Node { get; set; } = null!;

    public Guid? ServerId { get; set; }

    [ForeignKey("ServerId")]
    public GameServer? Server { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
