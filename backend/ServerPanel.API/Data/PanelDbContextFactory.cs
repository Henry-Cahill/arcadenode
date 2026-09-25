using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace ServerPanel.API.Data;

/// <summary>
/// Used only by the EF Core CLI (migrations add / database update). Keeps design-time
/// tooling from executing Program.cs (which seeds and connects at startup). The
/// connection string is read from the ConnectionStrings__DefaultConnection environment
/// variable; a placeholder is fine for "migrations add" since it does not open a connection.
/// </summary>
public class PanelDbContextFactory : IDesignTimeDbContextFactory<PanelDbContext>
{
    public PanelDbContext CreateDbContext(string[] args)
    {
        var connectionString =
            Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
            ?? "Server=localhost;Database=ArcadeNode;User Id=sa;Password=placeholder;TrustServerCertificate=True;";

        var options = new DbContextOptionsBuilder<PanelDbContext>()
            .UseSqlServer(connectionString)
            .Options;

        return new PanelDbContext(options);
    }
}
