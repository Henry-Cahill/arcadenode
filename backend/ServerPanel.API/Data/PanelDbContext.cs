using Microsoft.EntityFrameworkCore;
using ServerPanel.API.Models;

namespace ServerPanel.API.Data;

public class PanelDbContext : DbContext
{
    public PanelDbContext(DbContextOptions<PanelDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<GameServer> Servers { get; set; }
    public DbSet<Node> Nodes { get; set; }
    public DbSet<Egg> Eggs { get; set; }
    public DbSet<Nest> Nests { get; set; }
    public DbSet<Allocation> Allocations { get; set; }
    public DbSet<ApiKey> ApiKeys { get; set; }
    public DbSet<Backup> Backups { get; set; }
    public DbSet<Schedule> Schedules { get; set; }
    public DbSet<ScheduleTask> ScheduleTasks { get; set; }
    public DbSet<InviteCode> InviteCodes { get; set; }
    public DbSet<AuditLog> AuditLogs { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.Email).IsUnique();
        });

        // GameServer configuration
        modelBuilder.Entity<GameServer>(entity =>
        {
            entity.HasIndex(e => e.Identifier).IsUnique();
            
            entity.HasOne(e => e.Owner)
                .WithMany(u => u.Servers)
                .HasForeignKey(e => e.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Node)
                .WithMany(n => n.Servers)
                .HasForeignKey(e => e.NodeId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.Egg)
                .WithMany(e => e.Servers)
                .HasForeignKey(e => e.EggId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Node configuration
        modelBuilder.Entity<Node>(entity =>
        {
            entity.HasIndex(e => e.Fqdn).IsUnique();
        });

        // Allocation configuration
        modelBuilder.Entity<Allocation>(entity =>
        {
            entity.HasIndex(e => new { e.NodeId, e.IpAddress, e.Port }).IsUnique();

            entity.HasOne(e => e.Node)
                .WithMany(n => n.Allocations)
                .HasForeignKey(e => e.NodeId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Server)
                .WithMany(s => s.Allocations)
                .HasForeignKey(e => e.ServerId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Egg configuration
        modelBuilder.Entity<Egg>(entity =>
        {
            entity.HasOne(e => e.Nest)
                .WithMany(n => n.Eggs)
                .HasForeignKey(e => e.NestId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ApiKey configuration
        modelBuilder.Entity<ApiKey>(entity =>
        {
            entity.HasIndex(e => e.Identifier).IsUnique();

            entity.HasOne(e => e.User)
                .WithMany(u => u.ApiKeys)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Backup configuration
        modelBuilder.Entity<Backup>(entity =>
        {
            entity.HasOne(e => e.Server)
                .WithMany(s => s.Backups)
                .HasForeignKey(e => e.ServerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Schedule configuration
        modelBuilder.Entity<Schedule>(entity =>
        {
            entity.HasOne(e => e.Server)
                .WithMany(s => s.Schedules)
                .HasForeignKey(e => e.ServerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ScheduleTask configuration
        modelBuilder.Entity<ScheduleTask>(entity =>
        {
            entity.HasOne(e => e.Schedule)
                .WithMany(s => s.Tasks)
                .HasForeignKey(e => e.ScheduleId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // InviteCode configuration
        modelBuilder.Entity<InviteCode>(entity =>
        {
            entity.HasIndex(e => e.Code).IsUnique();

            entity.HasOne(e => e.CreatedByUser)
                .WithMany()
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // AuditLog configuration
        modelBuilder.Entity<AuditLog>(entity =>
        {
            entity.HasIndex(e => e.Timestamp);
            entity.HasIndex(e => e.UserId);
        });

        // NOTE: Admin user is seeded in Program.cs at runtime to ensure 
        // the bcrypt hash is generated fresh (not at compile time)

        // Seed default nest (static timestamps keep HasData deterministic for migrations)
        var seedDate = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        var minecraftNestId = Guid.Parse("00000000-0000-0000-0000-000000000002");
        modelBuilder.Entity<Nest>().HasData(new Nest
        {
            Id = minecraftNestId,
            Name = "Minecraft",
            Description = "Minecraft game servers including vanilla, Spigot, Paper, and modded servers.",
            Author = "admin@localhost",
            CreatedAt = seedDate,
            UpdatedAt = seedDate
        });

        // Seed Minecraft egg
        modelBuilder.Entity<Egg>().HasData(new Egg
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000003"),
            NestId = minecraftNestId,
            Name = "Paper",
            Description = "High performance Minecraft server using Paper",
            DockerImage = "ghcr.io/pterodactyl/yolks:java_17",
            StartupCommand = "java -Xms128M -Xmx{{SERVER_MEMORY}}M -jar server.jar",
            CreatedAt = seedDate,
            UpdatedAt = seedDate,
            Variables = @"[
                {""Name"":""Server JAR"",""EnvVariable"":""SERVER_JARFILE"",""DefaultValue"":""server.jar"",""UserViewable"":true,""UserEditable"":true},
                {""Name"":""Minecraft Version"",""EnvVariable"":""MINECRAFT_VERSION"",""DefaultValue"":""latest"",""UserViewable"":true,""UserEditable"":true}
            ]"
        });
    }
}
